# frozen_string_literal: true

require "test_helper"

class OidcUserinfoTest < ActionDispatch::IntegrationTest
  setup do
    @user = users(:family_admin)
    @application = Doorkeeper::Application.create!(
      name: "Test OIDC App",
      redirect_uri: "http://localhost/callback",
      scopes: "openid profile email read",
      confidential: false
    )
  end

  test "userinfo endpoint returns claims with openid and profile scopes" do
    token = Doorkeeper::AccessToken.create!(
      resource_owner_id: @user.id,
      application: @application,
      scopes: "openid profile email",
      expires_in: 1.hour
    )

    get "/oauth/userinfo",
        headers: { "Authorization" => "Bearer #{token.token}" }

    assert_response :success

    json = JSON.parse(response.body)
    assert_equal @user.id.to_s, json["sub"]
    assert_equal @user.email, json["email"]
    assert_equal @user.display_name, json["name"]
    assert_equal @user.first_name, json["given_name"]
    assert_equal @user.last_name, json["family_name"]
    assert_equal @user.family_id, json["family_id"]
    assert_equal @user.role, json["role"]
  end

  test "userinfo endpoint returns only sub with openid scope" do
    token = Doorkeeper::AccessToken.create!(
      resource_owner_id: @user.id,
      application: @application,
      scopes: "openid",
      expires_in: 1.hour
    )

    get "/oauth/userinfo",
        headers: { "Authorization" => "Bearer #{token.token}" }

    assert_response :success

    json = JSON.parse(response.body)
    assert_equal @user.id.to_s, json["sub"]
    assert_nil json["email"]
    assert_nil json["name"]
  end

  test "userinfo endpoint requires valid token" do
    get "/oauth/userinfo",
        headers: { "Authorization" => "Bearer invalid_token" }

    assert_response :unauthorized
  end
end
