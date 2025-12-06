class Provider::Anthropic::ChatParser
  Error = Class.new(StandardError)

  def initialize(response)
    @response = response
  end

  def parsed
    ChatResponse.new(
      id: response_id,
      model: response_model,
      messages: messages,
      function_requests: function_requests
    )
  end

  private
    attr_reader :response

    ChatResponse = Provider::LlmConcept::ChatResponse
    ChatMessage = Provider::LlmConcept::ChatMessage
    ChatFunctionRequest = Provider::LlmConcept::ChatFunctionRequest

    def response_id
      response["id"]
    end

    def response_model
      response["model"]
    end

    def content_blocks
      response["content"] || []
    end

    def messages
      text_blocks = content_blocks.select { |block| block["type"] == "text" }

      return [] if text_blocks.empty?

      # Combine all text blocks into a single message
      combined_text = text_blocks.map { |block| block["text"] }.join("\n")

      [
        ChatMessage.new(
          id: response_id,
          output_text: combined_text
        )
      ]
    end

    def function_requests
      tool_use_blocks = content_blocks.select { |block| block["type"] == "tool_use" }

      tool_use_blocks.map do |block|
        ChatFunctionRequest.new(
          id: block["id"],
          call_id: block["id"],
          function_name: block["name"],
          function_args: block["input"].to_json
        )
      end
    end
end
