# frozen_string_literal: true

require "test_helper"

class Api::V1::McpControllerTest < ActionDispatch::IntegrationTest
  setup do
    @user = users(:family_admin)
    @family = @user.family
    @api_key = api_keys(:active_key)
    Redis.new.del("api_rate_limit:#{@api_key.id}")
  end

  test "requires authentication" do
    post api_v1_mcp_path,
      params: { jsonrpc: "2.0", method: "tools/list", id: 1 }.to_json,
      headers: { "Content-Type" => "application/json" }

    assert_response :unauthorized
  end

  test "lists available tools" do
    post api_v1_mcp_path,
      params: { jsonrpc: "2.0", method: "tools/list", id: 1 }.to_json,
      headers: auth_headers

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

  test "executes ping tool successfully" do
    post api_v1_mcp_path,
      params: {
        jsonrpc: "2.0",
        method: "tools/call",
        params: { name: "ping", arguments: {} },
        id: 1
      }.to_json,
      headers: auth_headers

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

  test "executes list_accounts tool successfully" do
    post api_v1_mcp_path,
      params: {
        jsonrpc: "2.0",
        method: "tools/call",
        params: { name: "list_accounts", arguments: {} },
        id: 1
      }.to_json,
      headers: auth_headers

    assert_response :success
    response_data = JSON.parse(response.body)

    assert_nil response_data["error"]

    content = response_data.dig("result", "content")
    text_content = content.find { |c| c["type"] == "text" }
    result = JSON.parse(text_content["text"])

    assert result["accounts"].is_a?(Array)
    assert result["total_count"].is_a?(Integer)
  end

  test "list_accounts filters by account_type" do
    post api_v1_mcp_path,
      params: {
        jsonrpc: "2.0",
        method: "tools/call",
        params: {
          name: "list_accounts",
          arguments: { account_type: "depository" }
        },
        id: 1
      }.to_json,
      headers: auth_headers

    assert_response :success
    response_data = JSON.parse(response.body)
    content = response_data.dig("result", "content")
    text_content = content.find { |c| c["type"] == "text" }
    result = JSON.parse(text_content["text"])

    result["accounts"].each do |account|
      assert_equal "depository", account["account_type"]
    end
  end

  test "executes get_account tool successfully" do
    account = @family.accounts.visible.first

    post api_v1_mcp_path,
      params: {
        jsonrpc: "2.0",
        method: "tools/call",
        params: {
          name: "get_account",
          arguments: { account_id: account.id.to_s }
        },
        id: 1
      }.to_json,
      headers: auth_headers

    assert_response :success
    response_data = JSON.parse(response.body)

    assert_nil response_data["error"]

    content = response_data.dig("result", "content")
    text_content = content.find { |c| c["type"] == "text" }
    result = JSON.parse(text_content["text"])

    assert_equal account.id, result["id"]
    assert_equal account.name, result["name"]
    assert result["balance_history"].present?
  end

  test "get_account returns error for invalid account_id" do
    post api_v1_mcp_path,
      params: {
        jsonrpc: "2.0",
        method: "tools/call",
        params: {
          name: "get_account",
          arguments: { account_id: "invalid-id" }
        },
        id: 1
      }.to_json,
      headers: auth_headers

    assert_response :success
    response_data = JSON.parse(response.body)

    content = response_data.dig("result", "content")
    text_content = content.find { |c| c["type"] == "text" }
    result = JSON.parse(text_content["text"])

    assert_equal "Account not found", result["error"]
  end

  test "returns error for unknown method" do
    post api_v1_mcp_path,
      params: { jsonrpc: "2.0", method: "unknown/method", id: 1 }.to_json,
      headers: auth_headers

    assert_response :success
    response_data = JSON.parse(response.body)
    assert response_data["error"].present?
  end

  test "executes list_transactions tool successfully" do
    post api_v1_mcp_path,
      params: {
        jsonrpc: "2.0",
        method: "tools/call",
        params: {
          name: "list_transactions",
          arguments: {
            start_date: 1.year.ago.to_date.iso8601,
            limit: 10
          }
        },
        id: 1
      }.to_json,
      headers: auth_headers

    assert_response :success
    response_data = JSON.parse(response.body)

    assert_nil response_data["error"]

    content = response_data.dig("result", "content")
    text_content = content.find { |c| c["type"] == "text" }
    result = JSON.parse(text_content["text"])

    assert result["transactions"].is_a?(Array)
    assert result["pagination"].present?
    assert_equal 10, result["pagination"]["limit"]
  end

  test "list_transactions filters by account" do
    account = @family.accounts.visible.first

    post api_v1_mcp_path,
      params: {
        jsonrpc: "2.0",
        method: "tools/call",
        params: {
          name: "list_transactions",
          arguments: {
            account_id: account.id.to_s,
            start_date: 1.year.ago.to_date.iso8601
          }
        },
        id: 1
      }.to_json,
      headers: auth_headers

    assert_response :success
    response_data = JSON.parse(response.body)
    content = response_data.dig("result", "content")
    text_content = content.find { |c| c["type"] == "text" }
    result = JSON.parse(text_content["text"])

    result["transactions"].each do |txn|
      assert_equal account.id, txn["account"]["id"]
    end
  end

  test "executes query_transactions with multiple filters" do
    post api_v1_mcp_path,
      params: {
        jsonrpc: "2.0",
        method: "tools/call",
        params: {
          name: "query_transactions",
          arguments: {
            classification: "expense",
            min_amount: 10,
            start_date: 1.year.ago.to_date.iso8601,
            limit: 20
          }
        },
        id: 1
      }.to_json,
      headers: auth_headers

    assert_response :success
    response_data = JSON.parse(response.body)

    assert_nil response_data["error"]

    content = response_data.dig("result", "content")
    text_content = content.find { |c| c["type"] == "text" }
    result = JSON.parse(text_content["text"])

    assert result["transactions"].is_a?(Array)
    assert result["summary"].present?
    assert_equal "expense", result["filters_applied"]["classification"]

    result["transactions"].each do |txn|
      assert_equal "expense", txn["classification"]
      assert txn["amount"].abs >= 10
    end
  end

  test "executes financial_summary tool successfully" do
    post api_v1_mcp_path,
      params: {
        jsonrpc: "2.0",
        method: "tools/call",
        params: {
          name: "financial_summary",
          arguments: { period: "month" }
        },
        id: 1
      }.to_json,
      headers: auth_headers

    assert_response :success
    response_data = JSON.parse(response.body)

    assert_nil response_data["error"]

    content = response_data.dig("result", "content")
    text_content = content.find { |c| c["type"] == "text" }
    result = JSON.parse(text_content["text"])

    assert_equal "month", result["period"]["name"]
    assert result["net_worth"].present?
    assert result["cash_flow"].present?
    assert result["top_categories"].present?
  end

  test "financial_summary with quarter period and no comparison" do
    post api_v1_mcp_path,
      params: {
        jsonrpc: "2.0",
        method: "tools/call",
        params: {
          name: "financial_summary",
          arguments: {
            period: "quarter",
            compare_previous: false,
            top_count: 5
          }
        },
        id: 1
      }.to_json,
      headers: auth_headers

    assert_response :success
    response_data = JSON.parse(response.body)
    content = response_data.dig("result", "content")
    text_content = content.find { |c| c["type"] == "text" }
    result = JSON.parse(text_content["text"])

    assert_equal "quarter", result["period"]["name"]
    assert_nil result["cash_flow"]["previous_period"]
    assert result["top_categories"]["categories"].length <= 5
  end

  private

    def auth_headers
      {
        "Content-Type" => "application/json",
        "X-Api-Key" => @api_key.display_key
      }
    end
end
