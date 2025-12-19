# frozen_string_literal: true

require "test_helper"

class Mcp::Tools::QueryTransactionsTest < ActiveSupport::TestCase
  setup do
    @family = families(:dylan_family)
    @server_context = { family: @family }
  end

  test "returns transactions with summary by default" do
    response = Mcp::Tools::QueryTransactions.call(server_context: @server_context)

    assert response.is_a?(::MCP::Tool::Response)
    data = JSON.parse(response.content.first[:text])

    assert data["transactions"].is_a?(Array)
    assert data["pagination"].present?
    assert data["summary"].present?
    assert data["summary"]["total_income"].is_a?(Numeric)
    assert data["summary"]["total_expenses"].is_a?(Numeric)
    assert data["summary"]["net"].is_a?(Numeric)
  end

  test "excludes summary when requested" do
    response = Mcp::Tools::QueryTransactions.call(
      server_context: @server_context,
      include_summary: false
    )

    data = JSON.parse(response.content.first[:text])

    assert_nil data["summary"]
  end

  test "filters by category_id" do
    category = @family.categories.first
    skip "No categories in fixtures" unless category

    response = Mcp::Tools::QueryTransactions.call(
      server_context: @server_context,
      category_id: category.id.to_s
    )

    data = JSON.parse(response.content.first[:text])

    data["transactions"].each do |txn|
      if txn["category"]
        assert_equal category.id, txn["category"]["id"]
      end
    end
  end

  test "filters by category_names" do
    category = @family.categories.first
    skip "No categories in fixtures" unless category

    response = Mcp::Tools::QueryTransactions.call(
      server_context: @server_context,
      category_names: [ category.name ]
    )

    data = JSON.parse(response.content.first[:text])

    data["transactions"].each do |txn|
      if txn["category"]
        assert_equal category.name.downcase, txn["category"]["name"].downcase
      end
    end
  end

  test "filters uncategorized transactions" do
    response = Mcp::Tools::QueryTransactions.call(
      server_context: @server_context,
      uncategorized: true
    )

    data = JSON.parse(response.content.first[:text])

    data["transactions"].each do |txn|
      assert_nil txn["category"]
    end
  end

  test "filters by classification income" do
    response = Mcp::Tools::QueryTransactions.call(
      server_context: @server_context,
      classification: "income"
    )

    data = JSON.parse(response.content.first[:text])

    data["transactions"].each do |txn|
      assert_equal "income", txn["classification"]
    end
  end

  test "filters by classification expense" do
    response = Mcp::Tools::QueryTransactions.call(
      server_context: @server_context,
      classification: "expense"
    )

    data = JSON.parse(response.content.first[:text])

    data["transactions"].each do |txn|
      assert_equal "expense", txn["classification"]
    end
  end

  test "filters by min_amount" do
    response = Mcp::Tools::QueryTransactions.call(
      server_context: @server_context,
      min_amount: 100
    )

    data = JSON.parse(response.content.first[:text])

    data["transactions"].each do |txn|
      assert txn["amount"].abs >= 100
    end
  end

  test "filters by max_amount" do
    response = Mcp::Tools::QueryTransactions.call(
      server_context: @server_context,
      max_amount: 50
    )

    data = JSON.parse(response.content.first[:text])

    data["transactions"].each do |txn|
      assert txn["amount"].abs <= 50
    end
  end

  test "filters by amount range" do
    response = Mcp::Tools::QueryTransactions.call(
      server_context: @server_context,
      min_amount: 10,
      max_amount: 100
    )

    data = JSON.parse(response.content.first[:text])

    data["transactions"].each do |txn|
      assert txn["amount"].abs >= 10
      assert txn["amount"].abs <= 100
    end
  end

  test "filters by exact_amount" do
    txn = @family.transactions.joins(:entry).first
    skip "No transactions in fixtures" unless txn

    amount = txn.entry.amount.abs

    response = Mcp::Tools::QueryTransactions.call(
      server_context: @server_context,
      exact_amount: amount
    )

    data = JSON.parse(response.content.first[:text])

    data["transactions"].each do |t|
      assert (t["amount"].abs - amount).abs <= 0.01
    end
  end

  test "excludes transfers when requested" do
    response = Mcp::Tools::QueryTransactions.call(
      server_context: @server_context,
      exclude_transfers: true
    )

    data = JSON.parse(response.content.first[:text])

    data["transactions"].each do |txn|
      refute txn["is_transfer"]
    end
  end

  test "search finds by name" do
    txn = @family.transactions.joins(:entry).first
    skip "No transactions in fixtures" unless txn

    search_term = txn.entry.name[0..5]

    response = Mcp::Tools::QueryTransactions.call(
      server_context: @server_context,
      search: search_term
    )

    data = JSON.parse(response.content.first[:text])

    assert data["transactions"].any? { |t|
      t["name"].downcase.include?(search_term.downcase) ||
      (t["notes"] || "").downcase.include?(search_term.downcase)
    }
  end

  test "filters by date range" do
    start_date = 60.days.ago.to_date
    end_date = 30.days.ago.to_date

    response = Mcp::Tools::QueryTransactions.call(
      server_context: @server_context,
      start_date: start_date.iso8601,
      end_date: end_date.iso8601
    )

    data = JSON.parse(response.content.first[:text])

    data["transactions"].each do |txn|
      txn_date = Date.parse(txn["date"])
      assert txn_date >= start_date
      assert txn_date <= end_date
    end
  end

  test "summary includes expense breakdown by category" do
    response = Mcp::Tools::QueryTransactions.call(server_context: @server_context)

    data = JSON.parse(response.content.first[:text])

    assert data["summary"]["expense_by_category"].is_a?(Hash)
  end

  test "filters_applied shows active filters" do
    response = Mcp::Tools::QueryTransactions.call(
      server_context: @server_context,
      classification: "expense",
      min_amount: 10
    )

    data = JSON.parse(response.content.first[:text])

    assert_equal "expense", data["filters_applied"]["classification"]
    assert_equal 10, data["filters_applied"]["min_amount"]
  end

  test "raises error when family is missing" do
    assert_raises(ArgumentError) do
      Mcp::Tools::QueryTransactions.call(server_context: {})
    end
  end

  test "pagination works correctly" do
    response = Mcp::Tools::QueryTransactions.call(
      server_context: @server_context,
      limit: 5,
      offset: 0
    )

    data = JSON.parse(response.content.first[:text])

    assert data["pagination"]["limit"] == 5
    assert data["pagination"]["offset"] == 0
    assert data["transactions"].length <= 5
  end

  test "respects max limit" do
    response = Mcp::Tools::QueryTransactions.call(
      server_context: @server_context,
      limit: 1000
    )

    data = JSON.parse(response.content.first[:text])

    assert data["pagination"]["limit"] <= 500
  end

  test "filters by account_id" do
    account = @family.accounts.first
    skip "No accounts in fixtures" unless account

    response = Mcp::Tools::QueryTransactions.call(
      server_context: @server_context,
      account_id: account.id.to_s
    )

    data = JSON.parse(response.content.first[:text])

    data["transactions"].each do |txn|
      assert_equal account.id, txn["account"]["id"]
    end
  end
end
