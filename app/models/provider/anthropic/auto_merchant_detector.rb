class Provider::Anthropic::AutoMerchantDetector
  def initialize(client, transactions:, user_merchants:)
    @client = client
    @transactions = transactions
    @user_merchants = user_merchants
  end

  def auto_detect_merchants
    response = client.messages.create(
      model: "claude-sonnet-4-5-20250929",
      max_tokens: 4096,
      system: instructions,
      messages: [
        { role: "user", content: developer_message }
      ],
      tools: [ merchant_detection_tool ],
      tool_choice: { type: "tool", name: "submit_merchants" }
    )

    Rails.logger.info("Tokens used to auto-detect merchants: #{response['usage']['input_tokens'] + response['usage']['output_tokens']}")

    build_response(extract_merchants(response))
  end

  private
    attr_reader :client, :transactions, :user_merchants

    AutoDetectedMerchant = Provider::LlmConcept::AutoDetectedMerchant

    def build_response(merchants)
      merchants.map do |merchant|
        AutoDetectedMerchant.new(
          transaction_id: merchant["transaction_id"],
          business_name: normalize_ai_value(merchant["business_name"]),
          business_url: normalize_ai_value(merchant["business_url"]),
        )
      end
    end

    def normalize_ai_value(ai_value)
      return nil if ai_value == "null" || ai_value.nil?

      ai_value
    end

    def extract_merchants(response)
      content = response["content"]
      tool_use_block = content.find { |block| block["type"] == "tool_use" }

      return [] unless tool_use_block

      tool_use_block["input"]["merchants"] || []
    end

    def merchant_detection_tool
      {
        name: "submit_merchants",
        description: "Submit the detected merchant information for each transaction",
        input_schema: {
          type: "object",
          properties: {
            merchants: {
              type: "array",
              description: "An array of auto-detected merchant businesses for each transaction",
              items: {
                type: "object",
                properties: {
                  transaction_id: {
                    type: "string",
                    description: "The internal ID of the original transaction"
                  },
                  business_name: {
                    type: [ "string", "null" ],
                    description: "The detected business name of the transaction, or null if uncertain"
                  },
                  business_url: {
                    type: [ "string", "null" ],
                    description: "The URL of the detected business, or null if uncertain"
                  }
                },
                required: [ "transaction_id", "business_name", "business_url" ]
              }
            }
          },
          required: [ "merchants" ]
        }
      }
    end

    def developer_message
      <<~MESSAGE.strip_heredoc
        Here are the user's available merchants in JSON format:

        ```json
        #{user_merchants.to_json}
        ```

        Use BOTH your knowledge AND the user-generated merchants to auto-detect the following transactions:

        ```json
        #{transactions.to_json}
        ```

        Use the submit_merchants tool to return your results. Return null if you are not 80%+ confident in your answer.
      MESSAGE
    end

    def instructions
      <<~INSTRUCTIONS.strip_heredoc
        You are an assistant to a consumer personal finance app.

        Closely follow ALL the rules below while auto-detecting business names and website URLs:

        - Return 1 result per transaction
        - Correlate each transaction by ID (transaction_id)
        - Do not include the subdomain in the business_url (i.e. "amazon.com" not "www.amazon.com")
        - User merchants are considered "manual" user-generated merchants and should only be used in 100% clear cases
        - Be slightly pessimistic. We favor returning null over returning a false positive.
        - NEVER return a name or URL for generic transaction names (e.g. "Paycheck", "Laundromat", "Grocery store", "Local diner")

        Determining a value:

        - First attempt to determine the name + URL from your knowledge of global businesses
        - If no certain match, attempt to match one of the user-provided merchants
        - If no match, return null

        Example 1 (known business):

        ```
        Transaction name: "Some Amazon purchases"

        Result:
        - business_name: "Amazon"
        - business_url: "amazon.com"
        ```

        Example 2 (generic business):

        ```
        Transaction name: "local diner"

        Result:
        - business_name: null
        - business_url: null
        ```
      INSTRUCTIONS
    end
end
