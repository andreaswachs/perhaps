class Provider::Anthropic::AutoCategorizer
  def initialize(client, transactions: [], user_categories: [])
    @client = client
    @transactions = transactions
    @user_categories = user_categories
  end

  def auto_categorize
    response = client.messages.create(
      model: "claude-sonnet-4-5-20250929",
      max_tokens: 4096,
      system: instructions,
      messages: [
        { role: "user", content: developer_message }
      ],
      tools: [ categorization_tool ],
      tool_choice: { type: "tool", name: "submit_categorizations" }
    )

    Rails.logger.info("Tokens used to auto-categorize transactions: #{response['usage']['input_tokens'] + response['usage']['output_tokens']}")

    build_response(extract_categorizations(response))
  end

  private
    attr_reader :client, :transactions, :user_categories

    AutoCategorization = Provider::LlmConcept::AutoCategorization

    def build_response(categorizations)
      categorizations.map do |categorization|
        AutoCategorization.new(
          transaction_id: categorization["transaction_id"],
          category_name: normalize_category_name(categorization["category_name"]),
        )
      end
    end

    def normalize_category_name(category_name)
      return nil if category_name == "null" || category_name.nil?

      category_name
    end

    def extract_categorizations(response)
      content = response["content"]
      tool_use_block = content.find { |block| block["type"] == "tool_use" }

      return [] unless tool_use_block

      tool_use_block["input"]["categorizations"] || []
    end

    def categorization_tool
      {
        name: "submit_categorizations",
        description: "Submit the categorization results for each transaction",
        input_schema: {
          type: "object",
          properties: {
            categorizations: {
              type: "array",
              description: "An array of auto-categorizations for each transaction",
              items: {
                type: "object",
                properties: {
                  transaction_id: {
                    type: "string",
                    description: "The internal ID of the original transaction"
                  },
                  category_name: {
                    type: "string",
                    description: "The matched category name of the transaction, or 'null' if no match"
                  }
                },
                required: [ "transaction_id", "category_name" ]
              }
            }
          },
          required: [ "categorizations" ]
        }
      }
    end

    def developer_message
      <<~MESSAGE.strip_heredoc
        Here are the user's available categories in JSON format:

        ```json
        #{user_categories.to_json}
        ```

        Use the available categories to auto-categorize the following transactions:

        ```json
        #{transactions.to_json}
        ```

        Use the submit_categorizations tool to return your results. For each transaction, match it to the most appropriate category from the user's categories. Use "null" as the category_name if you cannot find a good match.
      MESSAGE
    end

    def instructions
      <<~INSTRUCTIONS.strip_heredoc
        You are an assistant to a consumer personal finance app. You will be provided a list
        of the user's transactions and a list of the user's categories. Your job is to auto-categorize
        each transaction.

        Closely follow ALL the rules below while auto-categorizing:

        - Return 1 result per transaction
        - Correlate each transaction by ID (transaction_id)
        - Attempt to match the most specific category possible (i.e. subcategory over parent category)
        - Category and transaction classifications should match (i.e. if transaction is an "expense", the category must have classification of "expense")
        - If you don't know the category, return "null"
          - You should always favor "null" over false positives
          - Be slightly pessimistic. Only match a category if you're 60%+ confident it is the correct one.
        - Each transaction has varying metadata that can be used to determine the category
          - Note: "hint" comes from 3rd party aggregators and typically represents a category name that
            may or may not match any of the user-supplied categories
      INSTRUCTIONS
    end
end
