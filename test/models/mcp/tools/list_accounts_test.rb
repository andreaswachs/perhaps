# frozen_string_literal: true

require "test_helper"

class Mcp::Tools::ListAccountsTest < ActiveSupport::TestCase
  setup do
    @family = families(:dylan_family)
    @server_context = { family: @family }
    @tool = Mcp::Tools::ListAccounts.new
  end

  test "returns all visible accounts for family" do
    response = Mcp::Tools::ListAccounts.call(server_context: @server_context)

    assert response.is_a?(::MCP::Tool::Response)

    content = response.content
    assert_equal 1, content.length
    assert_equal "text", content.first[:type]

    result = JSON.parse(content.first[:text])

    assert result["accounts"].is_a?(Array)
    assert result["total_count"].positive?

    # Verify account structure
    account = result["accounts"].first
    assert account["id"].present?
    assert account["name"].present?
    assert account["account_type"].present?
    assert account["currency"].present?
    assert account["balance"].is_a?(Numeric)
    assert account["balance_formatted"].present?
  end

  test "filters by account type" do
    response = Mcp::Tools::ListAccounts.call(
      server_context: @server_context,
      account_type: "depository"
    )

    content = response.content
    result = JSON.parse(content.first[:text])

    result["accounts"].each do |account|
      assert_equal "depository", account["account_type"]
    end

    assert_equal "depository", result["filters_applied"]["account_type"]
  end

  test "filters by classification" do
    response = Mcp::Tools::ListAccounts.call(
      server_context: @server_context,
      classification: "asset"
    )

    content = response.content
    result = JSON.parse(content.first[:text])

    result["accounts"].each do |account|
      assert_equal "asset", account["classification"]
    end
  end

  test "excludes inactive accounts by default" do
    # Get an account and disable it
    account = @family.accounts.visible.first
    account.disable! if account.may_disable?

    response = Mcp::Tools::ListAccounts.call(server_context: @server_context)

    content = response.content
    result = JSON.parse(content.first[:text])

    account_ids = result["accounts"].map { |a| a["id"] }
    refute_includes account_ids, account.id

    # Re-enable for other tests
    account.enable! if account.may_enable?
  end

  test "includes inactive accounts when requested" do
    # Get an account and disable it
    account = @family.accounts.visible.first
    original_status = account.status
    account.disable! if account.may_disable?

    response = Mcp::Tools::ListAccounts.call(
      server_context: @server_context,
      include_inactive: true
    )

    content = response.content
    result = JSON.parse(content.first[:text])

    account_ids = result["accounts"].map { |a| a["id"] }
    assert_includes account_ids, account.id

    # Restore original status
    account.enable! if account.may_enable? && original_status == "active"
  end

  test "returns accounts sorted alphabetically" do
    response = Mcp::Tools::ListAccounts.call(server_context: @server_context)

    content = response.content
    result = JSON.parse(content.first[:text])

    names = result["accounts"].map { |a| a["name"] }
    assert_equal names.sort, names
  end

  test "handles invalid account type gracefully" do
    response = Mcp::Tools::ListAccounts.call(
      server_context: @server_context,
      account_type: "invalid_type"
    )

    content = response.content
    result = JSON.parse(content.first[:text])

    # Should return all accounts (filter ignored)
    assert result["accounts"].is_a?(Array)
  end

  test "raises error when family is missing" do
    assert_raises(ArgumentError) do
      Mcp::Tools::ListAccounts.call(server_context: {})
    end
  end
end
