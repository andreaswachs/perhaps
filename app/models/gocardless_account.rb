class GocardlessAccount < ApplicationRecord
  belongs_to :gocardless_item

  has_one :account, dependent: :nullify

  validates :name, :currency, presence: true

  after_save :log_missing_balance_warning

  def upsert_gocardless_snapshot!(account_snapshot)
    assign_attributes(
      iban: account_snapshot["iban"],
      name: account_snapshot["name"] || account_snapshot["iban"] || "Account",
      owner_name: account_snapshot["ownerName"],
      currency: account_snapshot["currency"] || "EUR",
      account_type: account_snapshot["cashAccountType"],
      raw_payload: account_snapshot
    )

    save!
  end

  def upsert_gocardless_balances_snapshot!(balances_snapshot)
    balances = balances_snapshot["balances"] || []

    # GoCardless returns multiple balance types - extract the most relevant
    # Prefer closingBooked, then expected, then any available
    current = find_balance(balances, "closingBooked") ||
              find_balance(balances, "expected") ||
              balances.first
    available = find_balance(balances, "interimAvailable") ||
                find_balance(balances, "available")

    assign_attributes(
      current_balance: current&.dig("balanceAmount", "amount"),
      available_balance: available&.dig("balanceAmount", "amount"),
      raw_balances_payload: balances_snapshot
    )

    save!
  end

  def upsert_gocardless_transactions_snapshot!(transactions_snapshot)
    assign_attributes(
      raw_transactions_payload: transactions_snapshot
    )

    save!
  end

  private

    def find_balance(balances, type)
      balances.find { |b| b["balanceType"] == type }
    end

    def log_missing_balance_warning
      return if current_balance.present? || available_balance.present?
      Rails.logger.warn("GocardlessAccount #{id} has no balance data - will populate on next sync")
    end
end
