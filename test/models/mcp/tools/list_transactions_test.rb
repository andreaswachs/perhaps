# frozen_string_literal: true

require "test_helper"

class Mcp::Tools::ListTransactionsTest < ActiveSupport::TestCase
  setup do
    @family = families(:dylan_family)
    @server_context = { family: @family }
  end

  test "returns transactions with default date range" do
    response = Mcp::Tools::ListTransactions.call(server_context: @server_context)

    assert response.is_a?(::MCP::Tool::Response)
    content = response.content
    assert_equal 1, content.length
    assert_equal "text", content.first[:type]

    result = JSON.parse(content.first[:text])

    assert result["transactions"].is_a?(Array)
    assert result["pagination"].present?
    assert result["filters_applied"].present?

    # Default should be last 30 days
    assert_equal 30.days.ago.to_date.iso8601, result["filters_applied"]["start_date"]
    assert_equal Date.current.iso8601, result["filters_applied"]["end_date"]
  end

  test "transaction has correct structure" do
    response = Mcp::Tools::ListTransactions.call(server_context: @server_context)

    result = JSON.parse(response.content.first[:text])

    next skip "No transactions in fixtures" if result["transactions"].empty?

    txn = result["transactions"].first
    assert txn["id"].present?
    assert txn["date"].present?
    assert txn["name"].present?
    assert txn["amount"].is_a?(Numeric)
    assert txn["amount_formatted"].present?
    assert txn["currency"].present?
    assert %w[income expense].include?(txn["classification"])
    assert txn["account"].present?
    assert txn["account"]["id"].present?
    assert txn["account"]["name"].present?
  end

  test "filters by account_id" do
    account = @family.accounts.visible.first
    response = Mcp::Tools::ListTransactions.call(
      server_context: @server_context,
      account_id: account.id.to_s,
      start_date: 1.year.ago.to_date.iso8601
    )

    result = JSON.parse(response.content.first[:text])

    assert result["transactions"].is_a?(Array)
    result["transactions"].each do |txn|
      assert_equal account.id, txn["account"]["id"]
    end
  end

  test "filters by multiple account_ids" do
    accounts = @family.accounts.visible.limit(2)
    account_ids = accounts.pluck(:id).map(&:to_s)

    response = Mcp::Tools::ListTransactions.call(
      server_context: @server_context,
      account_ids: account_ids,
      start_date: 1.year.ago.to_date.iso8601
    )

    result = JSON.parse(response.content.first[:text])

    assert result["transactions"].is_a?(Array)
    result["transactions"].each do |txn|
      assert_includes account_ids.map(&:to_i), txn["account"]["id"]
    end
  end

  test "filters by date range" do
    start_date = 60.days.ago.to_date
    end_date = 30.days.ago.to_date

    response = Mcp::Tools::ListTransactions.call(
      server_context: @server_context,
      start_date: start_date.iso8601,
      end_date: end_date.iso8601
    )

    result = JSON.parse(response.content.first[:text])

    assert result["transactions"].is_a?(Array)
    result["transactions"].each do |txn|
      txn_date = Date.parse(txn["date"])
      assert txn_date >= start_date
      assert txn_date <= end_date
    end
  end

  test "respects limit parameter" do
    response = Mcp::Tools::ListTransactions.call(
      server_context: @server_context,
      limit: 5,
      start_date: 1.year.ago.to_date.iso8601
    )

    result = JSON.parse(response.content.first[:text])

    assert result["transactions"].length <= 5
    assert_equal 5, result["pagination"]["limit"]
  end

  test "enforces maximum limit" do
    response = Mcp::Tools::ListTransactions.call(
      server_context: @server_context,
      limit: 1000 # Over max
    )

    result = JSON.parse(response.content.first[:text])

    assert_equal 500, result["pagination"]["limit"]
  end

  test "pagination offset works correctly" do
    # Get first page
    first_response = Mcp::Tools::ListTransactions.call(
      server_context: @server_context,
      limit: 5,
      offset: 0,
      start_date: 1.year.ago.to_date.iso8601
    )

    first_page = JSON.parse(first_response.content.first[:text])

    # Get second page
    second_response = Mcp::Tools::ListTransactions.call(
      server_context: @server_context,
      limit: 5,
      offset: 5,
      start_date: 1.year.ago.to_date.iso8601
    )

    second_page = JSON.parse(second_response.content.first[:text])

    # If there are enough transactions, pages should be different
    if first_page["pagination"]["total_count"] > 5
      first_ids = first_page["transactions"].map { |t| t["id"] }
      second_ids = second_page["transactions"].map { |t| t["id"] }
      assert_empty first_ids & second_ids
    else
      assert first_page["pagination"]["total_count"] <= 5
    end
  end

  test "has_more pagination flag is correct" do
    response = Mcp::Tools::ListTransactions.call(
      server_context: @server_context,
      limit: 1,
      start_date: 1.year.ago.to_date.iso8601
    )

    result = JSON.parse(response.content.first[:text])

    expected_has_more = result["pagination"]["total_count"] > 1
    assert_equal expected_has_more, result["pagination"]["has_more"]
  end

  test "handles invalid date gracefully" do
    response = Mcp::Tools::ListTransactions.call(
      server_context: @server_context,
      start_date: "not-a-date"
    )

    result = JSON.parse(response.content.first[:text])

    # Should use default date
    assert result["transactions"].is_a?(Array)
    assert_equal 30.days.ago.to_date.iso8601, result["filters_applied"]["start_date"]
  end

  test "transactions ordered by date descending" do
    response = Mcp::Tools::ListTransactions.call(
      server_context: @server_context,
      start_date: 1.year.ago.to_date.iso8601
    )

    result = JSON.parse(response.content.first[:text])

    dates = result["transactions"].map { |t| Date.parse(t["date"]) }
    assert_equal dates.sort.reverse, dates
  end

  test "raises error when family is missing" do
    assert_raises(ArgumentError) do
      Mcp::Tools::ListTransactions.call(server_context: {})
    end
  end
end
