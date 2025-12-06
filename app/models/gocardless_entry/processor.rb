class GocardlessEntry::Processor
  # gocardless_transaction is the raw hash fetched from GoCardless API and converted to JSONB
  def initialize(gocardless_transaction, gocardless_account:, category_matcher:)
    @gocardless_transaction = gocardless_transaction
    @gocardless_account = gocardless_account
    @category_matcher = category_matcher
  end

  def process
    GocardlessAccount.transaction do
      entry = account.entries.find_or_initialize_by(plaid_id: transaction_id) do |e|
        e.entryable = Transaction.new
      end

      entry.assign_attributes(
        amount: amount,
        currency: currency,
        date: date
      )

      entry.enrich_attribute(
        :name,
        name,
        source: "gocardless"
      )

      # Try to match a category based on transaction name
      matched_category = category_matcher.match(name)

      if matched_category
        entry.transaction.enrich_attribute(
          :category_id,
          matched_category.id,
          source: "gocardless"
        )
      end
    end
  end

  private

  attr_reader :gocardless_transaction, :gocardless_account, :category_matcher

  def account
    gocardless_account.account
  end

  # GoCardless transaction ID - we reuse the plaid_id field on Entry for this
  def transaction_id
    gocardless_transaction["transactionId"] ||
      gocardless_transaction["internalTransactionId"] ||
      generate_fallback_id
  end

  def name
    # GoCardless has multiple name fields, try in order of preference
    gocardless_transaction["remittanceInformationUnstructured"] ||
      gocardless_transaction["remittanceInformationUnstructuredArray"]&.first ||
      gocardless_transaction["creditorName"] ||
      gocardless_transaction["debtorName"] ||
      "Transaction"
  end

  def amount
    # GoCardless amounts are signed: negative = debit (money out), positive = credit (money in)
    # Perhaps uses positive for outflows, negative for inflows (opposite convention)
    # So we negate the amount
    raw_amount = gocardless_transaction.dig("transactionAmount", "amount").to_d
    -raw_amount
  end

  def currency
    gocardless_transaction.dig("transactionAmount", "currency") ||
      gocardless_account.currency
  end

  def date
    # Prefer bookingDate over valueDate as it's the confirmed date
    Date.parse(
      gocardless_transaction["bookingDate"] ||
        gocardless_transaction["valueDate"] ||
        Date.current.to_s
    )
  end

  # Generate a deterministic fallback ID if transaction doesn't have one
  def generate_fallback_id
    data = [
      gocardless_account.gocardless_id,
      date.to_s,
      gocardless_transaction.dig("transactionAmount", "amount"),
      name
    ].join("-")

    Digest::SHA256.hexdigest(data)[0..31]
  end
end
