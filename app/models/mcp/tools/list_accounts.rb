# frozen_string_literal: true

module Mcp
  module Tools
    class ListAccounts < Base
      tool_name "list_accounts"
      description "List all financial accounts for the user's family. Returns account names, types, balances, and currencies. Use this to understand what accounts are available before querying transactions."

      input_schema do
        property :account_type, type: "string", description: "Filter by account type. Options: depository, investment, crypto, property, vehicle, other_asset, credit_card, loan, other_liability"
        property :classification, type: "string", description: "Filter by classification. Options: asset, liability"
        property :include_inactive, type: "boolean", description: "Include disabled/inactive accounts. Default: false"
      end

      class << self
        def call(server_context:, account_type: nil, classification: nil, include_inactive: false, **_args)
          family = server_context[:family] || raise(ArgumentError, "Missing family in server context")

          accounts = build_accounts_query(family, account_type, classification, include_inactive)

          result = {
            accounts: accounts.map { |account| format_account(account) },
            total_count: accounts.count,
            filters_applied: {
              account_type: account_type,
              classification: classification,
              include_inactive: include_inactive
            }
          }

          ::MCP::Tool::Response.new([ {
            type: "text",
            text: result.to_json
          } ])
        end

        private

          def build_accounts_query(family, account_type, classification, include_inactive)
            query = family.accounts

            # Apply visibility filter
            query = include_inactive ? query : query.visible

            # Apply account type filter
            if account_type.present?
              accountable_type = account_type.to_s.camelize
              if Accountable::TYPES.include?(accountable_type)
                query = query.where(accountable_type: accountable_type)
              end
            end

            # Apply classification filter
            if classification.present? && %w[asset liability].include?(classification)
              query = query.where(classification: classification)
            end

            query.alphabetically
          end

          def format_account(account)
            {
              id: account.id,
              name: account.name,
              account_type: account.accountable_type.underscore,
              classification: account.classification,
              balance: account.balance.to_f,
              balance_formatted: account.balance_money.format,
              currency: account.currency,
              status: account.status,
              institution: account.plaid_account&.plaid_item&.name,
              subtype: account.subtype,
              subtype_label: account.short_subtype_label,
              is_linked: account.linked?,
              updated_at: account.updated_at.iso8601
            }
          end
      end
    end
  end
end
