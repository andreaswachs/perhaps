# frozen_string_literal: true

class Api::V1::McpController < Api::V1::BaseController
  # Only allow read scope for MCP (all tools are read-only for now)
  before_action :ensure_read_scope

  def handle
    # Build server context with authenticated family
    server_context = {
      family: Current.family,
      user: Current.user
    }

    # Build a new MCP server instance with the current context
    server = Mcp::Server.build_with_context(server_context)
    response = server.handle_json(request.body.read)

    render json: response
  rescue JSON::ParserError => e
    render json: {
      jsonrpc: "2.0",
      error: {
        code: -32700,
        message: "Parse error: #{e.message}"
      },
      id: nil
    }, status: :bad_request
  rescue StandardError => e
    Rails.logger.error "MCP Error: #{e.message}"
    Rails.logger.error e.backtrace.join("\n")

    render json: {
      jsonrpc: "2.0",
      error: {
        code: -32603,
        message: "Internal error: #{e.message}"
      },
      id: nil
    }, status: :internal_server_error
  end

  private

    def ensure_read_scope
      authorize_scope!(:read)
    end
end
