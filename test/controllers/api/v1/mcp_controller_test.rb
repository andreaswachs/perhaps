# frozen_string_literal: true

require "test_helper"

class Api::V1::McpControllerTest < ActionDispatch::IntegrationTest
  setup do
    @user = users(:family_admin)
    @family = @user.family
    @mcp_app = Doorkeeper::Application.create!(
      name: "MCP Client",
      redirect_uri: "http://localhost/callback",
      scopes: "openid profile email read",
      confidential: false
    )
  end

  # OAuth Authentication Tests

  test "accepts valid oauth token with read scope" do
    token = create_oauth_token(scopes: "openid profile email read")

    post api_v1_mcp_url,
         headers: { "Authorization" => "Bearer #{token.token}" },
         params: { jsonrpc: "2.0", method: "tools/list", id: 1 }.to_json,
         as: :json

    assert_response :success
    json = JSON.parse(response.body)
    assert_equal "2.0", json["jsonrpc"]
  end

  test "accepts valid oauth token with read_write scope" do
    token = create_oauth_token(scopes: "openid profile email read_write")

    post api_v1_mcp_url,
         headers: { "Authorization" => "Bearer #{token.token}" },
         params: { jsonrpc: "2.0", method: "tools/list", id: 1 }.to_json,
         as: :json

    assert_response :success
  end

  test "rejects oauth token without read scope" do
    token = create_oauth_token(scopes: "openid profile email")

    post api_v1_mcp_url,
         headers: { "Authorization" => "Bearer #{token.token}" },
         params: { jsonrpc: "2.0", method: "tools/list", id: 1 }.to_json,
         as: :json

    assert_response :forbidden
    json = JSON.parse(response.body)
    assert_equal "insufficient_scope", json["error"]
  end

  test "rejects expired oauth token" do
    token = create_oauth_token(scopes: "openid profile read", expires_in: -1.hour)

    post api_v1_mcp_url,
         headers: { "Authorization" => "Bearer #{token.token}" },
         params: { jsonrpc: "2.0", method: "tools/list", id: 1 }.to_json,
         as: :json

    assert_response :unauthorized
  end

  test "rejects invalid oauth token" do
    post api_v1_mcp_url,
         headers: { "Authorization" => "Bearer invalid_token_12345" },
         params: { jsonrpc: "2.0", method: "tools/list", id: 1 }.to_json,
         as: :json

    assert_response :unauthorized
  end

  # API Key Rejection Tests

  test "rejects api key with deprecation message" do
    api_key = api_keys(:active_key)

    post api_v1_mcp_url,
         headers: { "X-Api-Key" => api_key.display_key },
         params: { jsonrpc: "2.0", method: "tools/list", id: 1 }.to_json,
         as: :json

    assert_response :unauthorized
    json = JSON.parse(response.body)

    assert_equal "authentication_method_not_supported", json["error"]
    assert_includes json["message"], "API keys are no longer supported"
    assert_includes json["message"], "OAuth 2.0 with OpenID Connect"

    # Check migration guide is present
    assert json["migration_guide"].present?
    assert json["required_authentication"].present?
    assert_equal [ "openid", "profile", "email", "read" ],
                 json["required_authentication"]["required_scopes"]
  end

  test "rejects request with no authentication" do
    post api_v1_mcp_url,
         params: { jsonrpc: "2.0", method: "tools/list", id: 1 }.to_json,
         as: :json

    assert_response :unauthorized
    json = JSON.parse(response.body)

    assert_equal "unauthorized", json["error"]
    assert_includes json["message"], "OAuth 2.0 Bearer token required"
  end

  # Functional Tests with OAuth

  test "lists available tools with oauth" do
    token = create_oauth_token(scopes: "openid profile email read")

    post api_v1_mcp_url,
         headers: {
           "Authorization" => "Bearer #{token.token}",
           "Content-Type" => "application/json"
         },
         params: { jsonrpc: "2.0", method: "tools/list", id: 1 }.to_json

    assert_response :success
    response_data = JSON.parse(response.body)

    assert_equal "2.0", response_data["jsonrpc"]
    assert response_data["result"]["tools"].is_a?(Array)

    # Verify ping and list_accounts tools are available
    tool_names = response_data["result"]["tools"].map { |t| t["name"] }
    assert_includes tool_names, "ping"
    assert_includes tool_names, "list_accounts"
    assert_includes tool_names, "get_account"
  end

  test "executes ping tool with oauth" do
    token = create_oauth_token(scopes: "openid profile email read")

    post api_v1_mcp_url,
         headers: {
           "Authorization" => "Bearer #{token.token}",
           "Content-Type" => "application/json"
         },
         params: {
           jsonrpc: "2.0",
           method: "tools/call",
           params: { name: "ping", arguments: {} },
           id: 1
         }.to_json

    assert_response :success
    response_data = JSON.parse(response.body)

    assert_equal "2.0", response_data["jsonrpc"]
    assert_nil response_data["error"]

    # Parse the tool result
    content = response_data.dig("result", "content")
    assert content.present?

    text_content = content.find { |c| c["type"] == "text" }
    assert text_content.present?

    result = JSON.parse(text_content["text"])
    assert_equal "ok", result["status"]
    assert_equal "perhaps-finance", result["server"]
    assert_equal @family.id, result["family_id"]
    assert_equal @family.currency, result["family_currency"]
  end

  # OIDC Scope Validation Tests

  test "requires openid scope for mcp access" do
    token = create_oauth_token(scopes: "profile email read")

    post api_v1_mcp_url,
         headers: { "Authorization" => "Bearer #{token.token}" },
         params: { jsonrpc: "2.0", method: "tools/list", id: 1 }.to_json,
         as: :json

    assert_response :forbidden
    json = JSON.parse(response.body)

    assert_equal "insufficient_scope", json["error"]
    assert_includes json["message"], "OpenID Connect"
    assert_includes json["missing_scopes"], "openid"
  end

  test "requires profile scope for mcp access" do
    token = create_oauth_token(scopes: "openid email read")

    post api_v1_mcp_url,
         headers: { "Authorization" => "Bearer #{token.token}" },
         params: { jsonrpc: "2.0", method: "tools/list", id: 1 }.to_json,
         as: :json

    assert_response :forbidden
    json = JSON.parse(response.body)

    assert_equal "insufficient_scope", json["error"]
    assert_includes json["missing_scopes"], "profile"
  end

  test "requires email scope for mcp access" do
    token = create_oauth_token(scopes: "openid profile read")

    post api_v1_mcp_url,
         headers: { "Authorization" => "Bearer #{token.token}" },
         params: { jsonrpc: "2.0", method: "tools/list", id: 1 }.to_json,
         as: :json

    assert_response :forbidden
    json = JSON.parse(response.body)

    assert_equal "insufficient_scope", json["error"]
    assert_includes json["missing_scopes"], "email"
  end

  test "requires read scope even with all oidc scopes" do
    token = create_oauth_token(scopes: "openid profile email")

    post api_v1_mcp_url,
         headers: { "Authorization" => "Bearer #{token.token}" },
         params: { jsonrpc: "2.0", method: "tools/list", id: 1 }.to_json,
         as: :json

    assert_response :forbidden
    json = JSON.parse(response.body)

    assert_equal "insufficient_scope", json["error"]
    assert_includes json["message"], "read"
  end

  test "accepts token with all required scopes" do
    token = create_oauth_token(scopes: "openid profile email read")

    post api_v1_mcp_url,
         headers: { "Authorization" => "Bearer #{token.token}" },
         params: { jsonrpc: "2.0", method: "tools/list", id: 1 }.to_json,
         as: :json

    assert_response :success
  end

  test "accepts token with read_write instead of read" do
    token = create_oauth_token(scopes: "openid profile email read_write")

    post api_v1_mcp_url,
         headers: { "Authorization" => "Bearer #{token.token}" },
         params: { jsonrpc: "2.0", method: "tools/list", id: 1 }.to_json,
         as: :json

    assert_response :success
  end

  test "provides helpful error for missing multiple scopes" do
    token = create_oauth_token(scopes: "read")

    post api_v1_mcp_url,
         headers: { "Authorization" => "Bearer #{token.token}" },
         params: { jsonrpc: "2.0", method: "tools/list", id: 1 }.to_json,
         as: :json

    assert_response :forbidden
    json = JSON.parse(response.body)

    assert_equal "insufficient_scope", json["error"]
    assert_equal [ "openid", "profile", "email" ], json["missing_scopes"]
    assert_equal [ "openid", "profile", "email", "read" ], json["required_scopes"]
    assert json["documentation"].present?
  end

  # Backward Compatibility Tests

  test "other api endpoints still accept api keys" do
    api_key = api_keys(:active_key)

    get api_v1_accounts_url,
        headers: { "X-Api-Key" => api_key.display_key }

    assert_response :success
  end

  private

    def create_oauth_token(scopes:, expires_in: 1.hour)
      Doorkeeper::AccessToken.create!(
        resource_owner_id: @user.id,
        application: @mcp_app,
        scopes: scopes,
        expires_in: expires_in
      )
    end
end
