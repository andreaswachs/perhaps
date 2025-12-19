# frozen_string_literal: true

module Mcp
  module Tools
    class FinancialSummary < Base
      tool_name "financial_summary"
      description "Get aggregate financial analytics including net worth, account balances by type, spending trends, income vs expenses, and category breakdowns. Use this for high-level financial health overview."

      input_schema do
        property :period, type: "string", description: "Analysis period: 'month', 'quarter', 'year', 'ytd' (year to date), or 'all'. Default: 'month'"
        property :compare_previous, type: "boolean", description: "Include comparison with previous period. Default: true"
        property :include_net_worth, type: "boolean", description: "Include net worth breakdown by account type. Default: true"
        property :include_cash_flow, type: "boolean", description: "Include income/expense analysis. Default: true"
        property :include_top_categories, type: "boolean", description: "Include top spending categories. Default: true"
        property :include_top_merchants, type: "boolean", description: "Include top merchants by spending. Default: true"
        property :top_count, type: "integer", description: "Number of top items to return. Default: 10"
      end

      VALID_PERIODS = %w[month quarter year ytd all].freeze
      DEFAULT_TOP_COUNT = 10

      class << self
        def call(server_context:, period: "month", compare_previous: true, include_net_worth: true, include_cash_flow: true, include_top_categories: true, include_top_merchants: true, top_count: nil, **_args)
          family = family_from_context(server_context)
          top_count = validate_top_count(top_count)

          date_range = calculate_date_range(period)
          previous_range = calculate_previous_range(period, date_range) if compare_previous

          result = {
            period: {
              name: period,
              start_date: date_range[:start_date].iso8601,
              end_date: date_range[:end_date].iso8601
            },
            currency: family.currency,
            generated_at: Time.current.iso8601
          }

          result[:net_worth] = calculate_net_worth(family) if include_net_worth
          result[:cash_flow] = calculate_cash_flow(family, date_range, previous_range) if include_cash_flow
          result[:top_categories] = calculate_top_categories(family, date_range, top_count) if include_top_categories
          result[:top_merchants] = calculate_top_merchants(family, date_range, top_count) if include_top_merchants

          ::MCP::Tool::Response.new([ {
            type: "text",
            text: result.to_json
          } ])
        end

        private

          def family_from_context(server_context)
            server_context[:family] || raise(ArgumentError, "Missing family in server context")
          end

          def validate_top_count(count)
            return DEFAULT_TOP_COUNT if count.nil?
            [ [ count.to_i, 1 ].max, 50 ].min
          end

          def calculate_date_range(period)
            today = Date.current

            case period.to_s.downcase
            when "month"
              { start_date: today.beginning_of_month, end_date: today }
            when "quarter"
              { start_date: today.beginning_of_quarter, end_date: today }
            when "year"
              { start_date: today.beginning_of_year, end_date: today }
            when "ytd"
              { start_date: today.beginning_of_year, end_date: today }
            when "all"
              { start_date: 100.years.ago.to_date, end_date: today }
            else
              { start_date: today.beginning_of_month, end_date: today }
            end
          end

          def calculate_previous_range(period, current_range)
            duration = current_range[:end_date] - current_range[:start_date]

            case period.to_s.downcase
            when "month"
              start_date = current_range[:start_date] - 1.month
              end_date = current_range[:end_date] - 1.month
            when "quarter"
              start_date = current_range[:start_date] - 3.months
              end_date = current_range[:end_date] - 3.months
            when "year", "ytd"
              start_date = current_range[:start_date] - 1.year
              end_date = current_range[:end_date] - 1.year
            else
              start_date = current_range[:start_date] - duration.days
              end_date = current_range[:start_date] - 1.day
            end

            { start_date: start_date, end_date: end_date }
          end

          def calculate_net_worth(family)
            accounts = family.accounts.visible

            asset_total = 0.0
            liability_total = 0.0
            by_type = {}

            # Group by accountable type
            accounts.group_by(&:accountable_type).each do |type, type_accounts|
              type_key = type.underscore
              type_total = type_accounts.sum(&:balance).to_f

              by_type[type_key] = {
                count: type_accounts.count,
                total: type_total,
                total_formatted: format_money(type_total, family.currency),
                accounts: type_accounts.map { |a| { id: a.id, name: a.name, balance: a.balance.to_f } }
              }

              # Determine if asset or liability based on typical classification
              if %w[Depository Investment Crypto Property Vehicle OtherAsset].include?(type)
                asset_total += type_total
              else
                liability_total += type_total.abs
              end
            end

            net_worth = (asset_total - liability_total).to_f

            {
              net_worth: net_worth,
              net_worth_formatted: format_money(net_worth, family.currency),
              total_assets: asset_total.to_f,
              total_assets_formatted: format_money(asset_total, family.currency),
              total_liabilities: liability_total.to_f,
              total_liabilities_formatted: format_money(liability_total, family.currency),
              account_count: accounts.count,
              by_account_type: by_type
            }
          end

          def calculate_cash_flow(family, date_range, previous_range)
            current = calculate_period_cash_flow(family, date_range)

            result = {
              current_period: current
            }

            if previous_range
              previous = calculate_period_cash_flow(family, previous_range)
              result[:previous_period] = previous
              result[:comparison] = calculate_comparison(current, previous)
            end

            result
          end

          def calculate_period_cash_flow(family, date_range)
            transactions = family.transactions
              .visible
              .joins(:entry)
              .where("entries.date >= ?", date_range[:start_date])
              .where("entries.date <= ?", date_range[:end_date])
              .where.not(kind: %w[funds_movement cc_payment])

            income = 0.0
            expenses = 0.0

            transactions.pluck("entries.amount").each do |amount|
              amount = amount.to_f
              if amount.negative?
                income += amount.abs
              else
                expenses += amount.abs
              end
            end

            savings_rate = income.positive? ? ((income - expenses) / income * 100).round(1) : 0

            {
              income: income.to_f,
              income_formatted: format_money(income, family.currency),
              expenses: expenses.to_f,
              expenses_formatted: format_money(expenses, family.currency),
              net: (income - expenses).to_f,
              net_formatted: format_money(income - expenses, family.currency),
              savings_rate: savings_rate.to_f,
              transaction_count: transactions.count,
              start_date: date_range[:start_date].iso8601,
              end_date: date_range[:end_date].iso8601
            }
          end

          def calculate_comparison(current, previous)
            income_change = calculate_change(current[:income], previous[:income])
            expense_change = calculate_change(current[:expenses], previous[:expenses])
            net_change = calculate_change(current[:net], previous[:net])

            {
              income_change: income_change[:amount],
              income_change_percent: income_change[:percent],
              expense_change: expense_change[:amount],
              expense_change_percent: expense_change[:percent],
              net_change: net_change[:amount],
              net_change_percent: net_change[:percent],
              spending_trend: expense_change[:amount].positive? ? "increasing" : "decreasing",
              savings_trend: current[:savings_rate] > previous[:savings_rate] ? "improving" : "declining"
            }
          end

          def calculate_change(current_value, previous_value)
            change = current_value - previous_value
            percent = previous_value.nonzero? ? (change / previous_value * 100).round(1) : 0

            { amount: change, percent: percent }
          end

          def calculate_top_categories(family, date_range, top_count)
            # Get expense transactions grouped by category
            category_totals = family.transactions
              .visible
              .joins(:entry)
              .where("entries.date >= ?", date_range[:start_date])
              .where("entries.date <= ?", date_range[:end_date])
              .where("entries.amount > 0")
              .where.not(kind: %w[funds_movement cc_payment])
              .group(:category_id)
              .sum("entries.amount")

            # Get category names
            categories = family.categories.where(id: category_totals.keys).index_by(&:id)

            # Build results
            results = category_totals.map do |category_id, total|
              category = categories[category_id]
              {
                id: category_id,
                name: category&.name || "Uncategorized",
                total: total.to_f,
                total_formatted: format_money(total, family.currency),
                transaction_count: family.transactions
                  .visible
                  .joins(:entry)
                  .where(category_id: category_id)
                  .where("entries.date >= ?", date_range[:start_date])
                  .where("entries.date <= ?", date_range[:end_date])
                  .count
              }
            end

            total_expenses = results.sum { |r| r[:total] }.to_f

            results = results.sort_by { |r| -r[:total] }.first(top_count)

            # Add percentage
            results.each do |r|
              r[:percentage] = total_expenses.positive? ? (r[:total] / total_expenses * 100).round(1).to_f : 0.0
            end

            {
              categories: results,
              total_categorized: total_expenses,
              total_categorized_formatted: format_money(total_expenses, family.currency)
            }
          end

          def calculate_top_merchants(family, date_range, top_count)
            # Get expense transactions grouped by merchant
            merchant_totals = family.transactions
              .visible
              .joins(:entry)
              .where("entries.date >= ?", date_range[:start_date])
              .where("entries.date <= ?", date_range[:end_date])
              .where("entries.amount > 0")
              .where.not(merchant_id: nil)
              .where.not(kind: %w[funds_movement cc_payment])
              .group(:merchant_id)
              .sum("entries.amount")

            # Get merchant names
            merchants = Merchant.where(id: merchant_totals.keys).index_by(&:id)

            # Build results
            results = merchant_totals.map do |merchant_id, total|
              merchant = merchants[merchant_id]
              {
                id: merchant_id,
                name: merchant&.name || "Unknown",
                total: total.to_f,
                total_formatted: format_money(total, family.currency),
                transaction_count: family.transactions
                  .visible
                  .joins(:entry)
                  .where(merchant_id: merchant_id)
                  .where("entries.date >= ?", date_range[:start_date])
                  .where("entries.date <= ?", date_range[:end_date])
                  .count
              }
            end

            results = results.sort_by { |r| -r[:total] }.first(top_count)

            total_merchant_spending = results.sum { |r| r[:total] }.to_f

            # Add percentage
            results.each do |r|
              r[:percentage] = total_merchant_spending.positive? ? (r[:total] / total_merchant_spending * 100).round(1).to_f : 0.0
            end

            {
              merchants: results,
              total: total_merchant_spending,
              total_formatted: format_money(total_merchant_spending, family.currency)
            }
          end

          def format_money(amount, currency)
            Money.new((amount * 100).to_i, currency).format
          end
      end
    end
  end
end
