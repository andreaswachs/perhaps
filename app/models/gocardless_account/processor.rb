class GocardlessAccount::Processor
  include GocardlessAccount::TypeMappable

  attr_reader :gocardless_account

  def initialize(gocardless_account)
    @gocardless_account = gocardless_account
  end

  def process
    process_account!
    process_transactions
  end

  private

  def family
    gocardless_account.gocardless_item.family
  end

  def process_account!
    GocardlessAccount.transaction do
      account = family.accounts.find_or_initialize_by(
        gocardless_account_id: gocardless_account.id
      )

      # Name is the only attribute a user can override for GoCardless accounts
      account.enrich_attributes(
        {
          name: gocardless_account.name,
          subtype: map_subtype(gocardless_account.account_type)
        },
        source: "gocardless"
      )

      account.assign_attributes(
        accountable: map_accountable(gocardless_account.account_type),
        balance: balance_amount,
        currency: gocardless_account.currency,
        cash_balance: balance_amount
      )

      account.save!

      # Create or update the current balance anchor valuation for event-sourced ledger
      account.set_current_balance(balance_amount)
    end
  end

  def process_transactions
    GocardlessAccount::Transactions::Processor.new(gocardless_account).process
  rescue => e
    report_exception(e)
  end

  def balance_amount
    gocardless_account.current_balance || gocardless_account.available_balance || 0
  end

  def report_exception(error)
    Sentry.capture_exception(error) do |scope|
      scope.set_tags(gocardless_account_id: gocardless_account.id)
    end
  end
end
