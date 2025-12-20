# frozen_string_literal: true

module Mcp
  module Tools
    class Ping < Base
      tool_name "ping"
      description "Test connectivity to the Perhaps MCP server. Returns server status and authenticated family info."

      input_schema do
        # No required parameters
      end

      class << self
        def call(server_context: nil, **_args)
          family = server_context&.dig(:family) || raise(ArgumentError, "Missing family in server context")

          result = {
            status: "ok",
            server: "perhaps-finance",
            version: "1.0.0",
            family_id: family.id,
            family_currency: family.currency,
            timestamp: Time.current.iso8601
          }

          ::MCP::Tool::Response.new([ {
            type: "text",
            text: result.to_json
          } ])
        end
      end
    end
  end
end
