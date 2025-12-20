# frozen_string_literal: true

module Mcp
  module Tools
    class Base < ::MCP::Tool
      protected

        def family_from_context(server_context)
          server_context[:family] || raise(ArgumentError, "Missing family in server context")
        end
    end
  end
end
