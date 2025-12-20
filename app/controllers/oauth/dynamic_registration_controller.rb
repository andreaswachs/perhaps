# frozen_string_literal: true

# OAuth 2.0 Dynamic Client Registration (RFC 7591)
# This endpoint allows MCP clients like Claude Code to register themselves
# automatically without manual OAuth application setup.
class Oauth::DynamicRegistrationController < ApplicationController
  skip_authentication
  skip_before_action :verify_authenticity_token
  skip_before_action :require_onboarding_and_upgrade

  before_action :force_json_format

  # POST /oauth/register
  # Creates a new OAuth application (client) dynamically
  def create
    metadata = client_metadata_params

    # Validate required fields
    unless metadata[:redirect_uris].present?
      return render_error("invalid_client_metadata", "redirect_uris is required")
    end

    # Build the OAuth application
    application = Doorkeeper::Application.new(
      name: metadata[:client_name] || generate_client_name,
      redirect_uri: normalize_redirect_uris(metadata[:redirect_uris]),
      scopes: determine_scopes(metadata[:scope]),
      confidential: metadata[:token_endpoint_auth_method] != "none"
    )

    if application.save
      render_registration_response(application, metadata)
    else
      render_error("invalid_client_metadata", application.errors.full_messages.join(", "))
    end
  end

  private

    def force_json_format
      request.format = :json
    end

    def client_metadata_params
      # RFC 7591 client metadata fields
      params.permit(
        :client_name,
        :client_uri,
        :logo_uri,
        :scope,
        :token_endpoint_auth_method,
        :grant_types,
        :response_types,
        :software_id,
        :software_version,
        redirect_uris: [],
        contacts: []
      ).to_h.with_indifferent_access
    end

    def generate_client_name
      "MCP Client #{SecureRandom.hex(4)}"
    end

    def normalize_redirect_uris(uris)
      # Doorkeeper expects redirect_uri as a newline-separated string
      Array(uris).join("\n")
    end

    def determine_scopes(requested_scope)
      # Default scopes for MCP clients that need full OIDC + read/write access + refresh tokens
      default_scopes = "openid profile email read read_write offline_access"

      if requested_scope.present?
        # Validate requested scopes against configured scopes
        requested = requested_scope.split
        allowed = Doorkeeper.config.scopes.to_a.map(&:to_s)
        valid_scopes = requested & allowed

        # Always ensure openid is included for OIDC-capable clients
        valid_scopes << "openid" unless valid_scopes.include?("openid")
        valid_scopes.join(" ")
      else
        default_scopes
      end
    end

    def render_registration_response(application, metadata)
      response_data = {
        client_id: application.uid,
        client_id_issued_at: application.created_at.to_i,
        redirect_uris: application.redirect_uri.split("\n"),
        client_name: application.name,
        token_endpoint_auth_method: application.confidential? ? "client_secret_basic" : "none",
        grant_types: [ "authorization_code", "refresh_token" ],
        response_types: [ "code" ],
        scope: application.scopes.to_s
      }

      # Include client_secret only for confidential clients
      if application.confidential?
        # Note: We can only return the secret on creation because it gets hashed
        response_data[:client_secret] = application.plaintext_secret || application.secret
      end

      # Include optional metadata if provided
      response_data[:client_uri] = metadata[:client_uri] if metadata[:client_uri].present?
      response_data[:logo_uri] = metadata[:logo_uri] if metadata[:logo_uri].present?
      response_data[:contacts] = metadata[:contacts] if metadata[:contacts].present?
      response_data[:software_id] = metadata[:software_id] if metadata[:software_id].present?
      response_data[:software_version] = metadata[:software_version] if metadata[:software_version].present?

      render json: response_data, status: :created
    end

    def render_error(error_code, description)
      render json: {
        error: error_code,
        error_description: description
      }, status: :bad_request
    end
end
