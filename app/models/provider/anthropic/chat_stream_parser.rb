class Provider::Anthropic::ChatStreamParser
  Error = Class.new(StandardError)

  def initialize
    @accumulated_response = {
      "id" => nil,
      "model" => nil,
      "content" => []
    }
    @current_content_block = nil
    @current_content_index = nil
  end

  def parse(event)
    type = event["type"]

    case type
    when "message_start"
      handle_message_start(event)
    when "content_block_start"
      handle_content_block_start(event)
    when "content_block_delta"
      handle_content_block_delta(event)
    when "content_block_stop"
      handle_content_block_stop(event)
    when "message_stop"
      handle_message_stop(event)
    end
  end

  private
    attr_reader :accumulated_response
    attr_accessor :current_content_block, :current_content_index

    Chunk = Provider::LlmConcept::ChatStreamChunk

    def handle_message_start(event)
      message = event["message"]
      accumulated_response["id"] = message["id"]
      accumulated_response["model"] = message["model"]
      nil
    end

    def handle_content_block_start(event)
      @current_content_index = event["index"]
      @current_content_block = event["content_block"].dup
      @current_content_block["text"] ||= "" if @current_content_block["type"] == "text"
      @current_content_block["input"] ||= {} if @current_content_block["type"] == "tool_use"
      nil
    end

    def handle_content_block_delta(event)
      delta = event["delta"]

      case delta["type"]
      when "text_delta"
        text = delta["text"]
        current_content_block["text"] += text if current_content_block
        Chunk.new(type: "output_text", data: text)
      when "input_json_delta"
        # Accumulate partial JSON for tool use
        if current_content_block && current_content_block["type"] == "tool_use"
          current_content_block["partial_json"] ||= ""
          current_content_block["partial_json"] += delta["partial_json"]
        end
        nil
      end
    end

    def handle_content_block_stop(_event)
      if current_content_block
        # Parse accumulated JSON for tool_use blocks
        if current_content_block["type"] == "tool_use" && current_content_block["partial_json"].present?
          begin
            current_content_block["input"] = JSON.parse(current_content_block["partial_json"])
          rescue JSON::ParserError
            current_content_block["input"] = {}
          end
          current_content_block.delete("partial_json")
        end

        accumulated_response["content"] << current_content_block
      end

      @current_content_block = nil
      @current_content_index = nil
      nil
    end

    def handle_message_stop(_event)
      parsed_response = Provider::Anthropic::ChatParser.new(accumulated_response).parsed
      Chunk.new(type: "response", data: parsed_response)
    end
end
