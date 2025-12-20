# frozen_string_literal: true

module Mcp
  class Server
    class << self
      def build_with_context(server_context)
        ::MCP::Server.new(
          name: "perhaps-finance",
          version: "1.0.0",
          tools: [ Mcp::Tools::Ping, Mcp::Tools::ListAccounts, Mcp::Tools::GetAccount, Mcp::Tools::ListTransactions, Mcp::Tools::QueryTransactions, Mcp::Tools::FinancialSummary ],
          server_context: server_context
        )
      end
    end
  end
end
