class Provider::Anthropic::ChatConfig
  def initialize(functions: [], function_results: [], previous_response_id: nil)
    @functions = functions
    @function_results = function_results
    @previous_response_id = previous_response_id
  end

  def tools
    return [] if functions.empty?

    functions.map do |fn|
      {
        name: fn[:name],
        description: fn[:description],
        input_schema: fn[:params_schema]
      }
    end
  end

  def build_messages(prompt)
    messages = []

    # Add the user message
    messages << { role: "user", content: prompt }

    # If we have function results, we need to add the assistant's tool_use and our tool_result
    if function_results.present?
      # Add assistant message with tool_use blocks
      tool_use_blocks = function_results.map do |fn_result|
        {
          type: "tool_use",
          id: fn_result[:call_id],
          name: fn_result[:name] || "function",
          input: {}
        }
      end

      messages << { role: "assistant", content: tool_use_blocks }

      # Add user message with tool_result blocks
      tool_result_blocks = function_results.map do |fn_result|
        {
          type: "tool_result",
          tool_use_id: fn_result[:call_id],
          content: fn_result[:output].is_a?(String) ? fn_result[:output] : fn_result[:output].to_json
        }
      end

      messages << { role: "user", content: tool_result_blocks }
    end

    messages
  end

  private
    attr_reader :functions, :function_results, :previous_response_id
end
