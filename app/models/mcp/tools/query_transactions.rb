# frozen_string_literal: true

module Mcp
  module Tools
    class QueryTransactions < Base
      tool_name "query_transactions"
      description "Advanced transaction search with filters for categories, merchants, amounts, text search, and more. Use this for complex financial queries and analysis."

      input_schema do
        # Account filters
        property :account_id, type: "string", description: "Filter by specific account ID"
        property :account_ids, type: "array", items: { type: "string" }, description: "Filter by multiple account IDs"

        # Date filters
        property :start_date, type: "string", description: "Start date (ISO 8601: YYYY-MM-DD)"
        property :end_date, type: "string", description: "End date (ISO 8601: YYYY-MM-DD)"

        # Category filters
        property :category_id, type: "string", description: "Filter by specific category ID"
        property :category_ids, type: "array", items: { type: "string" }, description: "Filter by multiple category IDs"
        property :category_names, type: "array", items: { type: "string" }, description: "Filter by category names (case-insensitive)"
        property :uncategorized, type: "boolean", description: "Only show uncategorized transactions"

        # Merchant filters
        property :merchant_id, type: "string", description: "Filter by specific merchant ID"
        property :merchant_ids, type: "array", items: { type: "string" }, description: "Filter by multiple merchant IDs"
        property :merchant_names, type: "array", items: { type: "string" }, description: "Filter by merchant names (case-insensitive partial match)"

        # Amount filters
        property :min_amount, type: "number", description: "Minimum absolute amount"
        property :max_amount, type: "number", description: "Maximum absolute amount"
        property :exact_amount, type: "number", description: "Exact absolute amount (with 0.01 tolerance)"

        # Type filters
        property :classification, type: "string", description: "Filter by classification: income or expense"
        property :kind, type: "string", description: "Transaction kind: standard, funds_movement, cc_payment, loan_payment, one_time"
        property :exclude_transfers, type: "boolean", description: "Exclude transfer transactions. Default: false"

        # Text search
        property :search, type: "string", description: "Search in transaction name, notes, and merchant name"

        # Tag filters
        property :tag_ids, type: "array", items: { type: "string" }, description: "Filter by tag IDs (transactions with ANY of these tags)"
        property :tag_names, type: "array", items: { type: "string" }, description: "Filter by tag names (case-insensitive)"

        # Pagination
        property :limit, type: "integer", description: "Maximum results. Default: 100, max: 500"
        property :offset, type: "integer", description: "Skip N results for pagination"

        # Aggregation
        property :include_summary, type: "boolean", description: "Include summary statistics. Default: true"
      end

      DEFAULT_LIMIT = 100
      MAX_LIMIT = 500

      class << self
        def call(server_context:, **params)
          family = family_from_context(server_context)

          # Build query with all filters
          transactions = build_query(family, params)

          # Calculate summary before pagination
          summary = params[:include_summary] != false ? calculate_summary(transactions, family) : nil

          # Get total count
          total_count = transactions.count

          # Apply pagination
          limit = validate_limit(params[:limit])
          offset = [ params[:offset].to_i, 0 ].max
          paginated = transactions.offset(offset).limit(limit)

          build_response(paginated, summary, total_count, limit, offset, params)
        end

        private

          def family_from_context(server_context)
            server_context[:family] || raise(ArgumentError, "Missing family in server context")
          end

          def validate_limit(limit)
            return DEFAULT_LIMIT if limit.nil?
            [ [ limit.to_i, 1 ].max, MAX_LIMIT ].min
          end

          def build_query(family, params)
            query = family.transactions
              .visible
              .joins(:entry)
              .includes(entry: :account, category: [], merchant: [], tags: [])

            query = apply_account_filters(query, params)
            query = apply_date_filters(query, params)
            query = apply_category_filters(query, params, family)
            query = apply_merchant_filters(query, params, family)
            query = apply_amount_filters(query, params)
            query = apply_type_filters(query, params)
            query = apply_search_filter(query, params)
            query = apply_tag_filters(query, params, family)

            query.order("entries.date DESC, entries.created_at DESC")
          end

          def apply_account_filters(query, params)
            if params[:account_id].present?
              query = query.where(entries: { account_id: params[:account_id] })
            elsif params[:account_ids].present?
              query = query.where(entries: { account_id: params[:account_ids] })
            end
            query
          end

          def apply_date_filters(query, params)
            if params[:start_date].present?
              start_date = parse_date(params[:start_date])
              query = query.where("entries.date >= ?", start_date) if start_date
            end

            if params[:end_date].present?
              end_date = parse_date(params[:end_date])
              query = query.where("entries.date <= ?", end_date) if end_date
            end

            query
          end

          def apply_category_filters(query, params, family)
            if params[:uncategorized]
              return query.where(category_id: nil)
            end

            if params[:category_id].present?
              query = query.where(category_id: params[:category_id])
            elsif params[:category_ids].present?
              query = query.where(category_id: params[:category_ids])
            elsif params[:category_names].present?
              category_ids = family.categories
                .where("LOWER(name) IN (?)", params[:category_names].map(&:downcase))
                .pluck(:id)
              query = query.where(category_id: category_ids)
            end

            query
          end

          def apply_merchant_filters(query, params, family)
            if params[:merchant_id].present?
              query = query.where(merchant_id: params[:merchant_id])
            elsif params[:merchant_ids].present?
              query = query.where(merchant_id: params[:merchant_ids])
            elsif params[:merchant_names].present?
              # Partial match on merchant names
              merchant_conditions = params[:merchant_names].map { |name| "LOWER(merchants.name) LIKE ?" }
              merchant_values = params[:merchant_names].map { |name| "%#{name.downcase}%" }

              query = query.joins(:merchant)
                .where(merchant_conditions.join(" OR "), *merchant_values)
            end

            query
          end

          def apply_amount_filters(query, params)
            if params[:exact_amount].present?
              amount = params[:exact_amount].to_f.abs
              query = query.where("ABS(ABS(entries.amount) - ?) <= 0.01", amount)
            else
              if params[:min_amount].present?
                query = query.where("ABS(entries.amount) >= ?", params[:min_amount].to_f.abs)
              end

              if params[:max_amount].present?
                query = query.where("ABS(entries.amount) <= ?", params[:max_amount].to_f.abs)
              end
            end

            query
          end

          def apply_type_filters(query, params)
            if params[:classification].present?
              case params[:classification].downcase
              when "income"
                query = query.where("entries.amount < 0")
              when "expense"
                query = query.where("entries.amount > 0")
              end
            end

            if params[:kind].present?
              query = query.where(kind: params[:kind])
            end

            if params[:exclude_transfers]
              query = query.where.not(kind: %w[funds_movement cc_payment loan_payment])
            end

            query
          end

          def apply_search_filter(query, params)
            return query unless params[:search].present?

            search_term = "%#{ActiveRecord::Base.sanitize_sql_like(params[:search])}%"

            query.left_joins(:merchant)
              .where(
                "entries.name ILIKE ? OR entries.notes ILIKE ? OR merchants.name ILIKE ?",
                search_term, search_term, search_term
              )
          end

          def apply_tag_filters(query, params, family)
            if params[:tag_ids].present?
              query = query.joins(:tags).where(tags: { id: params[:tag_ids] })
            elsif params[:tag_names].present?
              tag_ids = family.tags
                .where("LOWER(name) IN (?)", params[:tag_names].map(&:downcase))
                .pluck(:id)
              query = query.joins(:tags).where(tags: { id: tag_ids }) if tag_ids.any?
            end

            query
          end

          def calculate_summary(transactions, family)
            # Calculate income and expenses
            all_amounts = transactions.reorder(nil).pluck("entries.amount").map(&:to_f)

            total_income = 0.0
            total_expenses = 0.0

            all_amounts.each do |amount|
              if amount.negative?
                total_income += amount.abs
              else
                total_expenses += amount.abs
              end
            end

            # Category breakdown for expenses
            # Use reorder(nil) to remove the ordering from the query
            category_breakdown_results = transactions
              .reorder(nil)
              .where("entries.amount > 0")
              .group(:category_id)
              .sum("entries.amount")

            category_breakdown = category_breakdown_results
              .transform_keys { |id| id || "uncategorized" }
              .transform_values(&:to_f)

            # Resolve category names
            category_names = family.categories.where(id: category_breakdown.keys).pluck(:id, :name).to_h
            category_breakdown = category_breakdown.transform_keys do |id|
              id == "uncategorized" ? "Uncategorized" : category_names[id] || "Unknown"
            end

            {
              total_income: total_income,
              total_income_formatted: Money.new(total_income * 100, family.currency).format,
              total_expenses: total_expenses,
              total_expenses_formatted: Money.new(total_expenses * 100, family.currency).format,
              net: total_income - total_expenses,
              net_formatted: Money.new((total_income - total_expenses) * 100, family.currency).format,
              transaction_count: all_amounts.count,
              expense_by_category: category_breakdown.sort_by { |_, v| -v }.to_h
            }
          end

          def build_response(transactions, summary, total_count, limit, offset, params)
            response = {
              transactions: transactions.map { |txn| format_transaction(txn) },
              pagination: {
                limit: limit,
                offset: offset,
                total_count: total_count,
                has_more: (offset + limit) < total_count
              },
              filters_applied: extract_applied_filters(params)
            }

            response[:summary] = summary if summary

            ::MCP::Tool::Response.new([ {
              type: "text",
              text: response.to_json
            } ])
          end

          def extract_applied_filters(params)
            {
              account_id: params[:account_id],
              account_ids: params[:account_ids],
              start_date: params[:start_date],
              end_date: params[:end_date],
              category_id: params[:category_id],
              category_ids: params[:category_ids],
              category_names: params[:category_names],
              uncategorized: params[:uncategorized],
              merchant_id: params[:merchant_id],
              merchant_ids: params[:merchant_ids],
              merchant_names: params[:merchant_names],
              min_amount: params[:min_amount],
              max_amount: params[:max_amount],
              exact_amount: params[:exact_amount],
              classification: params[:classification],
              kind: params[:kind],
              exclude_transfers: params[:exclude_transfers],
              search: params[:search],
              tag_ids: params[:tag_ids],
              tag_names: params[:tag_names]
            }.compact
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

              account: {
                id: entry.account.id,
                name: entry.account.name,
                account_type: entry.account.accountable_type.underscore
              },

              category: transaction.category ? {
                id: transaction.category.id,
                name: transaction.category.name,
                classification: transaction.category.classification
              } : nil,

              merchant: transaction.merchant ? {
                id: transaction.merchant.id,
                name: transaction.merchant.name
              } : nil,

              tags: transaction.tags.map { |tag| { id: tag.id, name: tag.name } },

              notes: entry.notes,
              is_transfer: transaction.transfer?
            }
          end

          def parse_date(date_string)
            return nil if date_string.blank?
            Date.parse(date_string)
          rescue ArgumentError
            nil
          end
      end
    end
  end
end
