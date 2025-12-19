# frozen_string_literal: true

# OpenID Connect configuration for Doorkeeper
# This extends Doorkeeper with OIDC capabilities for the Perhaps MCP server
Doorkeeper::OpenidConnect.configure do
  # The issuer claim for ID tokens (the base URL of this application)
  issuer do |resource_owner, application|
    # Use configured base URL in production, localhost in development
    if Rails.env.production? && ENV["APP_HOST"].present?
      "https://#{ENV['APP_HOST']}"
    else
      "http://localhost:3000"
    end
  end

  # Private key for signing ID tokens (JWS)
  # In production, this should be loaded from an environment variable or secure key store
  # Note: signing_key expects a string directly, not a block
  signing_key(
    if ENV["OPENID_SIGNING_KEY"].present?
      ENV["OPENID_SIGNING_KEY"]
    else
      # For development, generate a key if it doesn't exist and persist it
      key_path = Rails.root.join("config", "openid_key.pem")
      if File.exist?(key_path)
        File.read(key_path)
      else
        # Generate and save a key for development
        key = OpenSSL::PKey::RSA.new(2048).to_pem
        File.write(key_path, key) rescue nil  # Ignore write errors in read-only environments
        key
      end
    end
  )

  # Subject claim uniquely identifies the user (use user ID)
  subject do |resource_owner, application|
    resource_owner.id.to_s
  end

  # Resource owner lookup from access token
  resource_owner_from_access_token do |access_token|
    User.find_by(id: access_token.resource_owner_id)
  end

  # Return the time when the user authenticated (required for OIDC auth_time claim)
  # Since we don't track sign-in times, we use created_at as a reasonable approximation
  auth_time_from_resource_owner do |resource_owner|
    resource_owner.created_at
  end

  # Define how long ID tokens are valid (1 year to match access tokens)
  expiration 1.year.to_i

  # Claims are attributes about the user that can be included in ID tokens
  # and returned from the UserInfo endpoint
  # Note: The claims block is evaluated with instance_eval, so it needs
  # to use method_missing pattern provided by ClaimsBuilder
  claims do
    # Each claim must be defined separately as a method call with a block
    # that receives (resource_owner, scopes) parameters

    # Standard OIDC 'sub' claim is always included
    claim :sub do |resource_owner, scopes|
      resource_owner.id.to_s
    end

    # Profile scope claims
    claim :name do |resource_owner, scopes|
      resource_owner.display_name if scopes.include?("profile")
    end

    claim :given_name do |resource_owner, scopes|
      resource_owner.first_name if scopes.include?("profile")
    end

    claim :family_name do |resource_owner, scopes|
      resource_owner.last_name if scopes.include?("profile")
    end

    claim :family_id do |resource_owner, scopes|
      resource_owner.family_id if scopes.include?("profile")
    end

    claim :role do |resource_owner, scopes|
      resource_owner.role if scopes.include?("profile")
    end

    # Email scope claims
    claim :email do |resource_owner, scopes|
      resource_owner.email if scopes.include?("email")
    end

    claim :email_verified do |resource_owner, scopes|
      !resource_owner.pending_email_change? if scopes.include?("email")
    end
  end
end
