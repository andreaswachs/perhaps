# frozen_string_literal: true

module Mcp
  module Tools
    class GetAccount < Base
      tool_name "get_account"
      description "Get detailed information about a specific account including balance, balance history, and metadata. Use the account ID from list_accounts."

      input_schema do
        property :account_id, type: "string", description: "The account ID to retrieve"
        property :include_balance_history, type: "boolean", description: "Include balance history summary (last 30, 90, 365 days). Default: true"
        required :account_id
      end

      class << self
        def call(server_context:, account_id:, include_balance_history: true, **_args)
          family = family_from_context(server_context)

          account = family.accounts.find_by(id: account_id)
          return error_response("Account not found") unless account

          result = format_account_details(account)
          result[:balance_history] = format_balance_history(account) if include_balance_history

          ::MCP::Tool::Response.new([ {
            type: "text",
            text: result.to_json
          } ])
        end

        private

          def family_from_context(server_context)
            server_context[:family] || raise(ArgumentError, "Missing family in server context")
          end

          def error_response(message)
            ::MCP::Tool::Response.new([ {
              type: "text",
              text: { error: message }.to_json
            } ])
          end

          def format_account_details(account)
            {
              id: account.id,
              name: account.name,
              account_type: account.accountable_type.underscore,
              account_type_display: account.accountable&.display_name,
              classification: account.classification,
              subtype: account.subtype,
              subtype_label: account.long_subtype_label,

              # Balance info
              balance: account.balance.to_f,
              balance_formatted: account.balance_money.format,
              currency: account.currency,

              # Cash balance for investment accounts
              cash_balance: account.cash_balance&.to_f,
              cash_balance_formatted: account.cash_balance_money&.format,

              # Status and metadata
              status: account.status,
              is_linked: account.linked?,
              institution: account.plaid_account&.plaid_item&.name,
              institution_domain: account.institution_domain,

              # Dates
              start_date: account.start_date&.iso8601,
              created_at: account.created_at.iso8601,
              updated_at: account.updated_at.iso8601,

              # Statistics
              entry_count: account.entries.visible.count,
              transaction_count: account.transactions.count,
              holdings_count: account.holdings.count
            }
          end

          def format_balance_history(account)
            balances = account.balances.order(date: :desc)

            {
              current: current_balance_info(account, balances),
              periods: {
                last_30_days: period_summary(balances, 30.days.ago.to_date),
                last_90_days: period_summary(balances, 90.days.ago.to_date),
                last_365_days: period_summary(balances, 365.days.ago.to_date)
              }
            }
          end

          def current_balance_info(account, balances)
            latest_balance = balances.first

            {
              balance: account.balance.to_f,
              balance_formatted: account.balance_money.format,
              as_of: latest_balance&.date&.iso8601 || Date.current.iso8601
            }
          end

          def period_summary(balances, start_date)
            period_balances = balances.where("date >= ?", start_date)
            return nil if period_balances.empty?

            start_balance = period_balances.order(date: :asc).first
            end_balance = period_balances.order(date: :desc).first

            change = end_balance.balance - start_balance.balance
            change_percent = start_balance.balance.nonzero? ? (change / start_balance.balance * 100).round(2) : 0

            {
              start_balance: start_balance.balance.to_f,
              end_balance: end_balance.balance.to_f,
              change: change.to_f,
              change_percent: change_percent,
              start_date: start_balance.date.iso8601,
              end_date: end_balance.date.iso8601,
              data_points: period_balances.count
            }
          end
      end
    end
  end
end
