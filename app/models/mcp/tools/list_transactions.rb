# frozen_string_literal: true

module Mcp
  module Tools
    class ListTransactions < Base
      tool_name "list_transactions"
      description "List transactions for the user's family with basic filtering. Returns transaction details including date, amount, category, merchant, and account. Use query_transactions for advanced filtering."

      input_schema do
        property :account_id, type: "string", description: "Filter by specific account ID"
        property :account_ids, type: "array", items: { type: "string" }, description: "Filter by multiple account IDs"
        property :start_date, type: "string", description: "Start date (ISO 8601 format: YYYY-MM-DD). Default: 30 days ago"
        property :end_date, type: "string", description: "End date (ISO 8601 format: YYYY-MM-DD). Default: today"
        property :limit, type: "integer", description: "Maximum number of transactions to return. Default: 100, max: 500"
        property :offset, type: "integer", description: "Number of transactions to skip for pagination. Default: 0"
      end

      DEFAULT_LIMIT = 100
      MAX_LIMIT = 500
      DEFAULT_DAYS_BACK = 30

      class << self
        def call(server_context:, account_id: nil, account_ids: nil, start_date: nil, end_date: nil, limit: nil, offset: nil, **_args)
          family = family_from_context(server_context)

          # Parse and validate parameters
          parsed_start_date = parse_date(start_date) || DEFAULT_DAYS_BACK.days.ago.to_date
          parsed_end_date = parse_date(end_date) || Date.current
          parsed_limit = validate_limit(limit)
          parsed_offset = [ offset.to_i, 0 ].max

          # Build query
          transactions = build_transactions_query(
            family: family,
            account_id: account_id,
            account_ids: account_ids,
            start_date: parsed_start_date,
            end_date: parsed_end_date
          )

          # Get total count before pagination
          total_count = transactions.count

          # Apply pagination
          transactions = transactions
            .offset(parsed_offset)
            .limit(parsed_limit)

          result = {
            transactions: transactions.map { |txn| format_transaction(txn) },
            pagination: {
              limit: parsed_limit,
              offset: parsed_offset,
              total_count: total_count,
              has_more: (parsed_offset + parsed_limit) < total_count
            },
            filters_applied: {
              account_id: account_id,
              account_ids: account_ids,
              start_date: parsed_start_date.iso8601,
              end_date: parsed_end_date.iso8601
            }
          }

          ::MCP::Tool::Response.new([ {
            type: "text",
            text: result.to_json
          } ])
        end

        private

          def family_from_context(server_context)
            server_context[:family] || raise(ArgumentError, "Missing family in server context")
          end

          def parse_date(date_string)
            return nil if date_string.blank?
            Date.parse(date_string)
          rescue ArgumentError
            nil
          end

          def validate_limit(limit)
            return DEFAULT_LIMIT if limit.nil?
            [ [ limit.to_i, 1 ].max, MAX_LIMIT ].min
          end

          def build_transactions_query(family:, account_id:, account_ids:, start_date:, end_date:)
            query = family.transactions
              .visible
              .joins(:entry)
              .includes(entry: :account, category: [], merchant: [], tags: [])
              .where("entries.date >= ?", start_date)
              .where("entries.date <= ?", end_date)

            # Apply account filter
            if account_id.present?
              query = query.where(entries: { account_id: account_id })
            elsif account_ids.present?
              query = query.where(entries: { account_id: account_ids })
            end

            query.order("entries.date DESC, entries.created_at DESC")
          end

          def format_transaction(transaction)
            entry = transaction.entry

            {
              id: transaction.id,
              date: entry.date.iso8601,
              name: entry.name,
              amount: entry.amount.to_f,
              amount_formatted: entry.amount_money.format,
              currency: entry.currency,
              classification: entry.classification,
              kind: transaction.kind,

              # Account
              account: {
                id: entry.account.id,
                name: entry.account.name,
                account_type: entry.account.accountable_type.underscore
              },

              # Category
              category: transaction.category ? {
                id: transaction.category.id,
                name: transaction.category.name,
                classification: transaction.category.classification
              } : nil,

              # Merchant
              merchant: transaction.merchant ? {
                id: transaction.merchant.id,
                name: transaction.merchant.name
              } : nil,

              # Tags
              tags: transaction.tags.map { |tag| { id: tag.id, name: tag.name } },

              # Notes
              notes: entry.notes,

              # Transfer info
              is_transfer: transaction.transfer?,
              transfer_type: transaction.transfer? ? transaction.kind : nil,

              # Timestamps
              created_at: transaction.created_at.iso8601,
              updated_at: transaction.updated_at.iso8601
            }
          end
      end
    end
  end
end
