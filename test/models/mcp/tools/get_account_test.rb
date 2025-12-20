# frozen_string_literal: true

require "test_helper"

class Mcp::Tools::GetAccountTest < ActiveSupport::TestCase
  setup do
    @family = families(:dylan_family)
    @account = @family.accounts.visible.first
    @server_context = { family: @family }
  end

  test "returns detailed account information" do
    response = Mcp::Tools::GetAccount.call(
      server_context: @server_context,
      account_id: @account.id.to_s
    )

    assert response.is_a?(::MCP::Tool::Response)

    content = response.content
    assert_equal 1, content.length
    assert_equal "text", content.first[:type]

    result = JSON.parse(content.first[:text])

    # Basic info
    assert_equal @account.id, result["id"]
    assert_equal @account.name, result["name"]
    assert_equal @account.accountable_type.underscore, result["account_type"]
    assert_equal @account.classification, result["classification"]
    assert_equal @account.currency, result["currency"]

    # Balance
    assert_equal @account.balance.to_f, result["balance"]
    assert result["balance_formatted"].present?

    # Status
    assert_equal @account.status, result["status"]

    # Statistics
    assert result["entry_count"].is_a?(Integer)
    assert result["transaction_count"].is_a?(Integer)
  end

  test "includes balance history by default" do
    response = Mcp::Tools::GetAccount.call(
      server_context: @server_context,
      account_id: @account.id.to_s
    )

    content = response.content
    result = JSON.parse(content.first[:text])

    assert result["balance_history"].present?
    assert result["balance_history"]["current"].present?
    assert result["balance_history"]["periods"].present?
  end

  test "excludes balance history when requested" do
    response = Mcp::Tools::GetAccount.call(
      server_context: @server_context,
      account_id: @account.id.to_s,
      include_balance_history: false
    )

    content = response.content
    result = JSON.parse(content.first[:text])

    assert_nil result["balance_history"]
  end

  test "returns error for non-existent account" do
    response = Mcp::Tools::GetAccount.call(
      server_context: @server_context,
      account_id: "non-existent-id"
    )

    content = response.content
    result = JSON.parse(content.first[:text])

    assert_equal "Account not found", result["error"]
  end

  test "returns error for account from different family" do
    other_family = families(:empty)
    other_context = { family: other_family }

    response = Mcp::Tools::GetAccount.call(
      server_context: other_context,
      account_id: @account.id.to_s
    )

    content = response.content
    result = JSON.parse(content.first[:text])

    assert_equal "Account not found", result["error"]
  end

  test "includes cash balance for investment accounts" do
    # Find or create an investment account
    investment_account = @family.accounts.where(accountable_type: "Investment").first

    if investment_account
      response = Mcp::Tools::GetAccount.call(
        server_context: @server_context,
        account_id: investment_account.id.to_s
      )

      content = response.content
      result = JSON.parse(content.first[:text])

      assert result.key?("cash_balance")
      assert result.key?("cash_balance_formatted")
    else
      skip "No investment account available in fixtures"
    end
  end

  test "balance history periods include change calculations" do
    response = Mcp::Tools::GetAccount.call(
      server_context: @server_context,
      account_id: @account.id.to_s
    )

    content = response.content
    result = JSON.parse(content.first[:text])

    period = result.dig("balance_history", "periods", "last_30_days")

    if period # May be nil if no balance data
      assert period.key?("start_balance")
      assert period.key?("end_balance")
      assert period.key?("change")
      assert period.key?("change_percent")
      assert period.key?("data_points")
    else
      # Ensure test has at least one assertion
      assert result["balance_history"].present?
    end
  end

  test "raises error when family is missing" do
    assert_raises(ArgumentError) do
      Mcp::Tools::GetAccount.call(server_context: {}, account_id: @account.id.to_s)
    end
  end
end
