# frozen_string_literal: true

require "test_helper"

class OauthDynamicRegistrationTest < ActionDispatch::IntegrationTest
  test "openid-configuration discovery endpoint includes registration_endpoint" do
    get "/.well-known/openid-configuration"

    assert_response :success
    config = JSON.parse(response.body)

    # Verify registration_endpoint is present
    assert config["registration_endpoint"].present?, "registration_endpoint should be present"
    assert_match %r{/oauth/register$}, config["registration_endpoint"]

    # Verify other required OIDC fields
    assert config["issuer"].present?
    assert config["authorization_endpoint"].present?
    assert config["token_endpoint"].present?
    assert config["jwks_uri"].present?
    assert config["scopes_supported"].present?
  end

  test "oauth-authorization-server endpoint includes registration_endpoint" do
    get "/.well-known/oauth-authorization-server"

    assert_response :success
    config = JSON.parse(response.body)

    # Verify registration_endpoint is present (RFC 7591)
    assert config["registration_endpoint"].present?, "registration_endpoint should be present"
    assert_match %r{/oauth/register$}, config["registration_endpoint"]

    # Verify required OAuth 2.0 Authorization Server Metadata fields (RFC 8414)
    assert config["issuer"].present?
    assert config["authorization_endpoint"].present?
    assert config["token_endpoint"].present?
  end

  test "oauth-protected-resource endpoint returns resource metadata" do
    get "/.well-known/oauth-protected-resource"

    assert_response :success
    config = JSON.parse(response.body)

    # Verify RFC 9728 Protected Resource Metadata fields
    assert config["resource"].present?
    assert_match %r{/api/v1/mcp$}, config["resource"]
    assert config["authorization_servers"].is_a?(Array)
    assert config["authorization_servers"].length >= 1
    assert config["scopes_supported"].is_a?(Array)
    assert config["bearer_methods_supported"].include?("header")
  end

  test "oauth-protected-resource with path returns same metadata" do
    get "/.well-known/oauth-protected-resource/api/v1/mcp"

    assert_response :success
    config = JSON.parse(response.body)

    # Should return the same protected resource metadata regardless of path
    assert config["resource"].present?
    assert config["authorization_servers"].is_a?(Array)
  end

  test "dynamic client registration creates new oauth application" do
    assert_difference("Doorkeeper::Application.count", 1) do
      post "/oauth/register",
        params: {
          redirect_uris: [ "https://client.example.com/callback" ],
          client_name: "Test MCP Client"
        },
        as: :json
    end

    assert_response :created
    response_body = JSON.parse(response.body)

    # Verify required response fields (RFC 7591)
    assert response_body["client_id"].present?
    assert response_body["client_id_issued_at"].present?
    assert_equal [ "https://client.example.com/callback" ], response_body["redirect_uris"]
    assert_equal "Test MCP Client", response_body["client_name"]
    assert response_body["scope"].present?
  end

  test "dynamic client registration with custom scopes" do
    post "/oauth/register",
      params: {
        redirect_uris: [ "https://client.example.com/callback" ],
        client_name: "Custom Scope Client",
        scope: "openid profile email read"
      },
      as: :json

    assert_response :created
    response_body = JSON.parse(response.body)

    # Verify scopes are validated and set
    assert_includes response_body["scope"], "openid"
    assert_includes response_body["scope"], "read"
  end

  test "dynamic client registration fails without redirect_uris" do
    assert_no_difference("Doorkeeper::Application.count") do
      post "/oauth/register",
        params: { client_name: "No Redirect Client" },
        as: :json
    end

    assert_response :bad_request
    response_body = JSON.parse(response.body)
    assert_equal "invalid_client_metadata", response_body["error"]
  end

  test "dynamic client registration creates public client with token_endpoint_auth_method none" do
    post "/oauth/register",
      params: {
        redirect_uris: [ "claude://oauth/callback" ],
        client_name: "Claude Code Client",
        token_endpoint_auth_method: "none"
      },
      as: :json

    assert_response :created
    response_body = JSON.parse(response.body)

    # Public clients should not receive a client_secret
    assert_nil response_body["client_secret"]
    assert_equal "none", response_body["token_endpoint_auth_method"]
  end

  test "dynamic client registration supports multiple redirect URIs" do
    post "/oauth/register",
      params: {
        redirect_uris: [
          "https://client.example.com/callback",
          "http://localhost:8080/callback",
          "claude://oauth/callback"
        ],
        client_name: "Multi-Redirect Client"
      },
      as: :json

    assert_response :created
    response_body = JSON.parse(response.body)

    assert_equal 3, response_body["redirect_uris"].length
    assert_includes response_body["redirect_uris"], "https://client.example.com/callback"
    assert_includes response_body["redirect_uris"], "claude://oauth/callback"
  end

  test "registered client can be used for OAuth flow" do
    # First register a client
    post "/oauth/register",
      params: {
        redirect_uris: [ "https://test.example.com/callback" ],
        client_name: "OAuth Flow Test Client"
      },
      as: :json

    assert_response :created
    client_id = JSON.parse(response.body)["client_id"]

    # Verify the client can be found
    app = Doorkeeper::Application.find_by(uid: client_id)
    assert app.present?, "Registered application should exist"
    assert_equal "OAuth Flow Test Client", app.name
  end
end
