# frozen_string_literal: true

require "test_helper"

class Mcp::Tools::FinancialSummaryTest < ActiveSupport::TestCase
  setup do
    @family = families(:dylan_family)
    @server_context = { family: @family }
  end

  test "returns complete summary with defaults" do
    result = Mcp::Tools::FinancialSummary.call(server_context: @server_context)

    assert result.is_a?(::MCP::Tool::Response)
    content = result.content.first[:text]
    data = JSON.parse(content)

    assert data["period"].present?
    assert_equal "month", data["period"]["name"]
    assert data["currency"].present?
    assert data["generated_at"].present?

    # All sections included by default
    assert data["net_worth"].present?
    assert data["cash_flow"].present?
    assert data["top_categories"].present?
    assert data["top_merchants"].present?
  end

  test "net_worth includes breakdown by account type" do
    result = Mcp::Tools::FinancialSummary.call(server_context: @server_context)
    data = JSON.parse(result.content.first[:text])

    net_worth = data["net_worth"]
    assert net_worth["net_worth"].is_a?(Numeric)
    assert net_worth["total_assets"].is_a?(Numeric)
    assert net_worth["total_liabilities"].is_a?(Numeric)
    assert net_worth["account_count"].is_a?(Integer)
    assert net_worth["by_account_type"].is_a?(Hash)
  end

  test "cash_flow includes current and previous period comparison" do
    result = Mcp::Tools::FinancialSummary.call(server_context: @server_context)
    data = JSON.parse(result.content.first[:text])

    cash_flow = data["cash_flow"]
    assert cash_flow["current_period"].present?
    assert cash_flow["current_period"]["income"].is_a?(Numeric)
    assert cash_flow["current_period"]["expenses"].is_a?(Numeric)
    assert cash_flow["current_period"]["savings_rate"].is_a?(Numeric)

    # By default compare_previous is true, so we expect comparison when there is prior data
    assert cash_flow["previous_period"].present?
    assert cash_flow["comparison"].present?
    assert %w[increasing decreasing].include?(cash_flow["comparison"]["spending_trend"])
  end

  test "excludes comparison when compare_previous is false" do
    result = Mcp::Tools::FinancialSummary.call(
      server_context: @server_context,
      compare_previous: false
    )
    data = JSON.parse(result.content.first[:text])

    assert data["cash_flow"]["current_period"].present?
    assert_nil data["cash_flow"]["previous_period"]
    assert_nil data["cash_flow"]["comparison"]
  end

  test "top_categories returns categorized spending" do
    result = Mcp::Tools::FinancialSummary.call(server_context: @server_context)
    data = JSON.parse(result.content.first[:text])

    top_categories = data["top_categories"]
    assert top_categories["categories"].is_a?(Array)
    assert top_categories["total_categorized"].is_a?(Numeric)

    if top_categories["categories"].any?
      category = top_categories["categories"].first
      assert category["name"].present?
      assert category["total"].is_a?(Numeric)
      assert category["percentage"].is_a?(Numeric)
    end
  end

  test "top_merchants returns merchant spending" do
    result = Mcp::Tools::FinancialSummary.call(server_context: @server_context)
    data = JSON.parse(result.content.first[:text])

    top_merchants = data["top_merchants"]
    assert top_merchants["merchants"].is_a?(Array)
    assert top_merchants["total"].is_a?(Numeric)
  end

  test "respects top_count parameter" do
    result = Mcp::Tools::FinancialSummary.call(
      server_context: @server_context,
      top_count: 3
    )
    data = JSON.parse(result.content.first[:text])

    assert data["top_categories"]["categories"].length <= 3
    assert data["top_merchants"]["merchants"].length <= 3
  end

  test "different periods work correctly" do
    %w[month quarter year ytd all].each do |period|
      result = Mcp::Tools::FinancialSummary.call(
        server_context: @server_context,
        period: period
      )
      data = JSON.parse(result.content.first[:text])

      assert_equal period, data["period"]["name"]
      assert data["period"]["start_date"].present?
      assert data["period"]["end_date"].present?
    end
  end

  test "can exclude individual sections" do
    result = Mcp::Tools::FinancialSummary.call(
      server_context: @server_context,
      include_net_worth: false,
      include_cash_flow: false,
      include_top_categories: false,
      include_top_merchants: false
    )
    data = JSON.parse(result.content.first[:text])

    assert_nil data["net_worth"]
    assert_nil data["cash_flow"]
    assert_nil data["top_categories"]
    assert_nil data["top_merchants"]

    # Period info should always be present
    assert data["period"].present?
    assert data["currency"].present?
  end

  test "handles family with no data gracefully" do
    empty_family = families(:empty)
    context = { family: empty_family }

    result = Mcp::Tools::FinancialSummary.call(server_context: context)
    data = JSON.parse(result.content.first[:text])

    assert_equal 0, data["net_worth"]["net_worth"]
    assert_equal 0, data["cash_flow"]["current_period"]["income"]
    assert data["top_categories"]["categories"].empty?
  end

  test "raises error when family is missing" do
    assert_raises(ArgumentError) do
      Mcp::Tools::FinancialSummary.call(server_context: {})
    end
  end
end
