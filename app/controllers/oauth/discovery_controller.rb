# frozen_string_literal: true

# Custom OpenID Connect Discovery Controller
# Extends the default doorkeeper-openid_connect discovery to include
# registration_endpoint for RFC 7591 Dynamic Client Registration
class Oauth::DiscoveryController < ApplicationController
  skip_authentication
  skip_before_action :verify_authenticity_token
  skip_before_action :require_onboarding_and_upgrade

  # GET /.well-known/openid-configuration
  # GET /.well-known/oauth-authorization-server
  def show
    render json: openid_configuration
  end

  # GET /.well-known/oauth-protected-resource
  # RFC 9728 - OAuth Protected Resource Metadata
  # Tells clients where to find the authorization server for this resource
  def protected_resource
    issuer_url = base_url

    render json: {
      resource: "#{issuer_url}/api/v1/mcp",
      authorization_servers: [ issuer_url ],
      scopes_supported: Doorkeeper.config.scopes.to_a,
      bearer_methods_supported: [ "header" ],
      resource_documentation: "#{issuer_url}/docs/MCP_SERVER.md"
    }
  end

  private

    def openid_configuration
      issuer_url = base_url

      {
        issuer: issuer_url,
        authorization_endpoint: "#{issuer_url}/oauth/authorize",
        token_endpoint: "#{issuer_url}/oauth/token",
        revocation_endpoint: "#{issuer_url}/oauth/revoke",
        introspection_endpoint: "#{issuer_url}/oauth/introspect",
        userinfo_endpoint: "#{issuer_url}/oauth/userinfo",
        jwks_uri: "#{issuer_url}/oauth/discovery/keys",

        # RFC 7591 Dynamic Client Registration endpoint
        registration_endpoint: "#{issuer_url}/oauth/register",

        # Supported features
        scopes_supported: Doorkeeper.config.scopes.to_a,
        response_types_supported: [ "code" ],
        response_modes_supported: [ "query", "fragment" ],
        grant_types_supported: [ "authorization_code", "refresh_token" ],
        token_endpoint_auth_methods_supported: [ "client_secret_basic", "client_secret_post", "none" ],
        code_challenge_methods_supported: [ "S256" ],

        # OIDC specific
        subject_types_supported: [ "public" ],
        id_token_signing_alg_values_supported: [ "RS256" ],
        claims_supported: %w[sub iss aud exp iat name given_name family_name email email_verified family_id role]
      }
    end

    def base_url
      if Rails.env.production? && ENV["APP_HOST"].present?
        "https://#{ENV['APP_HOST']}"
      else
        request.base_url
      end
    end
end
