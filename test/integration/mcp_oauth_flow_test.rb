# frozen_string_literal: true

require "test_helper"

class McpOauthFlowTest < ActionDispatch::IntegrationTest
  setup do
    @user = users(:family_admin)
    @mcp_app = Doorkeeper::Application.create!(
      name: "MCP Client",
      redirect_uri: "claude://oauth/callback\nhttp://localhost:3000/oauth/callback",
      scopes: "openid profile email read read_write",
      confidential: false
    )
  end

  test "mcp oauth application exists with correct configuration" do
    assert_not_nil @mcp_app
    assert_equal "MCP Client", @mcp_app.name
    assert_includes @mcp_app.scopes.to_a, "openid"
    assert_includes @mcp_app.scopes.to_a, "profile"
    assert_includes @mcp_app.scopes.to_a, "email"
    assert_includes @mcp_app.scopes.to_a, "read"
    assert_equal false, @mcp_app.confidential
  end

  test "mcp app allows multiple redirect uris" do
    redirect_uris = @mcp_app.redirect_uri.split("\n")

    assert_includes redirect_uris, "claude://oauth/callback"
    assert_includes redirect_uris, "http://localhost:3000/oauth/callback"
  end

  test "mcp app allows all required scopes" do
    scopes = @mcp_app.scopes.to_a

    assert_includes scopes, "openid"
    assert_includes scopes, "profile"
    assert_includes scopes, "email"
    assert_includes scopes, "read"
    assert_includes scopes, "read_write"
  end

  test "access token can be created for mcp app with correct scopes" do
    token = Doorkeeper::AccessToken.create!(
      resource_owner_id: @user.id,
      application: @mcp_app,
      scopes: "openid profile email read",
      expires_in: 1.hour
    )

    assert_not_nil token.token
    assert_equal @user.id, token.resource_owner_id
    assert_equal @mcp_app.id, token.application_id
    assert_includes token.scopes.to_a, "openid"
    assert_includes token.scopes.to_a, "profile"
    assert_includes token.scopes.to_a, "email"
    assert_includes token.scopes.to_a, "read"
  end

  test "userinfo endpoint works with mcp app token" do
    token = Doorkeeper::AccessToken.create!(
      resource_owner_id: @user.id,
      application: @mcp_app,
      scopes: "openid profile email read",
      expires_in: 1.hour
    )

    get "/oauth/userinfo",
        headers: { "Authorization" => "Bearer #{token.token}" }

    assert_response :success

    json = JSON.parse(response.body)
    assert_equal @user.id.to_s, json["sub"]
    assert_equal @user.email, json["email"]
    assert_equal @user.display_name, json["name"]
  end
end
