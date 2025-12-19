# frozen_string_literal: true

# MCP (Model Context Protocol) Controller
#
# Authentication: OAuth 2.0 Bearer tokens only (API keys not supported)
# Required Scopes:
#   - openid: OpenID Connect authentication (required)
#   - profile: User profile information (required)
#   - email: User email and verification status (required)
#   - read: Read access to financial data (required)
#   - read_write: Write access to financial data (optional)
#
# Scope Validation Order:
#   1. OAuth-only authentication (rejects API keys)
#   2. OIDC scopes validation (openid, profile, email)
#   3. Data scope validation (read or read_write)
#
class Api::V1::McpController < Api::V1::BaseController
  # Override base controller authentication to require OAuth only
  # This is intentionally done BEFORE the base authentication runs
  skip_before_action :authenticate_request!
  skip_before_action :check_api_key_rate_limit
  before_action :authenticate_oauth_only!
  before_action :require_full_oidc_scopes!

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

    # Authenticate using OAuth only - reject API keys
    def authenticate_oauth_only!
      # Check if this is an API key authentication attempt
      if request.headers["X-Api-Key"].present?
        render_api_key_deprecation_error
        return false
      end

      # Try OAuth authentication (without scope enforcement at this level)
      return if authenticate_oauth_without_scope_check

      # No valid authentication provided
      render_oauth_required_error unless performed?
    end

    # Authenticate OAuth token without enforcing scope requirements
    # Scopes are checked separately in ensure_read_scope
    def authenticate_oauth_without_scope_check
      access_token = Doorkeeper::OAuth::Token.authenticate(
        request,
        *Doorkeeper.configuration.access_token_methods
      )

      # Check if no token was provided at all
      unless access_token
        # No valid authentication provided
        return false
      end

      # Check token validity (but not scope)
      unless !access_token.expired?
        render_json({ error: "unauthorized", message: "Access token is expired" }, status: :unauthorized)
        return false
      end

      # Set the doorkeeper_token for compatibility
      @_doorkeeper_token = access_token

      if doorkeeper_token&.resource_owner_id
        @current_user = User.find_by(id: doorkeeper_token.resource_owner_id)

        # If user doesn't exist, the token is invalid (user was deleted)
        unless @current_user
          Rails.logger.warn "API OAuth Token Invalid: Access token resource_owner_id #{doorkeeper_token.resource_owner_id} does not exist"
          render_json({ error: "unauthorized", message: "Access token is invalid - user not found" }, status: :unauthorized)
          return false
        end
      else
        Rails.logger.warn "API OAuth Token Invalid: Access token missing resource_owner_id"
        render_json({ error: "unauthorized", message: "Access token is invalid - missing resource owner" }, status: :unauthorized)
        return false
      end

      @authentication_method = :oauth
      setup_current_context_for_api
      true
    rescue Doorkeeper::Errors::DoorkeeperError => e
      Rails.logger.warn "API OAuth Error: #{e.message}"
      render_json({ error: "unauthorized", message: "OAuth authentication failed" }, status: :unauthorized)
      false
    end

    # Render a helpful error for API key attempts
    def render_api_key_deprecation_error
      render_json({
        error: "authentication_method_not_supported",
        message: "API keys are no longer supported for MCP access. Please use OAuth 2.0 with OpenID Connect.",
        documentation: "https://github.com/perhaps-finance/perhaps/blob/main/docs/MCP_SERVER.md#oidc-authentication",
        required_authentication: {
          type: "OAuth 2.0 + OpenID Connect",
          authorization_endpoint: "#{request.base_url}/oauth/authorize",
          token_endpoint: "#{request.base_url}/oauth/token",
          userinfo_endpoint: "#{request.base_url}/oauth/userinfo",
          discovery_endpoint: "#{request.base_url}/.well-known/openid-configuration",
          required_scopes: [ "openid", "profile", "email", "read" ]
        },
        migration_guide: {
          step_1: "Create an OAuth application or use the generic MCP Client",
          step_2: "Implement OAuth 2.0 authorization code flow with PKCE",
          step_3: "Request scopes: openid profile email read",
          step_4: "Use the access token in Authorization header: 'Bearer YOUR_TOKEN'"
        }
      }, status: :unauthorized)
    end

    # Render error when no authentication provided
    def render_oauth_required_error
      render_json({
        error: "unauthorized",
        message: "OAuth 2.0 Bearer token required. API keys are not supported for MCP access.",
        documentation: "https://github.com/perhaps-finance/perhaps/blob/main/docs/MCP_SERVER.md#oidc-authentication",
        authorization_endpoint: "#{request.base_url}/oauth/authorize",
        discovery_endpoint: "#{request.base_url}/.well-known/openid-configuration"
      }, status: :unauthorized)
    end

    def ensure_read_scope
      authorize_scope!(:read)
    end
end
