class Provider::Anthropic < Provider
  include LlmConcept

  # Subclass so errors caught in this provider are raised as Provider::Anthropic::Error
  Error = Class.new(Provider::Error)

  # Model configurations with user-friendly names
  MODELS = {
    "claude-haiku-4-5-20250929" => {
      name: "Fast",
      description: "Quick responses, lower cost",
      tier: :fast
    },
    "claude-sonnet-4-5-20250929" => {
      name: "Intelligent",
      description: "Best quality, complex reasoning",
      tier: :intelligent
    }
  }.freeze

  DEFAULT_MODEL = "claude-sonnet-4-5-20250929"
  FAST_MODEL = "claude-haiku-4-5-20250929"

  def self.available_models
    MODELS.map do |model_id, config|
      {
        id: model_id,
        name: config[:name],
        description: config[:description],
        tier: config[:tier]
      }
    end
  end

  def self.default_model
    DEFAULT_MODEL
  end

  def initialize(api_key)
    @client = ::Anthropic::Client.new(api_key: api_key)
  end

  def supports_model?(model)
    MODELS.key?(model)
  end

  def auto_categorize(transactions: [], user_categories: [])
    with_provider_response do
      raise Error, "Too many transactions to auto-categorize. Max is 25 per request." if transactions.size > 25

      AutoCategorizer.new(
        client,
        transactions: transactions,
        user_categories: user_categories
      ).auto_categorize
    end
  end

  def auto_detect_merchants(transactions: [], user_merchants: [])
    with_provider_response do
      raise Error, "Too many transactions to auto-detect merchants. Max is 25 per request." if transactions.size > 25

      AutoMerchantDetector.new(
        client,
        transactions: transactions,
        user_merchants: user_merchants
      ).auto_detect_merchants
    end
  end

  def chat_response(prompt, model:, instructions: nil, functions: [], function_results: [], streamer: nil, previous_response_id: nil)
    with_provider_response do
      chat_config = ChatConfig.new(
        functions: functions,
        function_results: function_results,
        previous_response_id: previous_response_id
      )

      collected_chunks = []

      # Build request parameters
      request_params = {
        model: model,
        max_tokens: 4096,
        messages: chat_config.build_messages(prompt)
      }

      # Add system prompt if instructions provided
      request_params[:system] = instructions if instructions.present?

      # Add tools if functions provided
      request_params[:tools] = chat_config.tools if functions.present?

      if streamer.present?
        # Streaming response
        stream_parser = ChatStreamParser.new

        client.messages.create(**request_params) do |event|
          parsed_chunk = stream_parser.parse(event)

          unless parsed_chunk.nil?
            streamer.call(parsed_chunk)
            collected_chunks << parsed_chunk
          end
        end

        # Return the response chunk from the stream
        response_chunk = collected_chunks.find { |chunk| chunk.type == "response" }
        response_chunk.data
      else
        # Non-streaming response
        raw_response = client.messages.create(**request_params)
        ChatParser.new(raw_response).parsed
      end
    end
  end

  private
    attr_reader :client
end
