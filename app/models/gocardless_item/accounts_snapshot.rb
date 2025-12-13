class GocardlessItem::AccountsSnapshot
  def initialize(gocardless_item, gocardless_provider:)
    @gocardless_item = gocardless_item
    @gocardless_provider = gocardless_provider
  end

  def accounts
    @accounts ||= requisition_data["accounts"] || []
  end

  def get_account_data(account_id)
    AccountData.new(
      account_data: fetch_account_details(account_id),
      balances_data: fetch_account_balances(account_id),
      transactions_data: fetch_account_transactions(account_id)
    )
  end

  private

    attr_reader :gocardless_item, :gocardless_provider

    AccountData = Data.define(:account_data, :balances_data, :transactions_data)

    def requisition_data
      @requisition_data ||= gocardless_provider.get_requisition(
        gocardless_item.requisition_id
      )
    end

    def fetch_account_details(account_id)
      gocardless_provider.get_account_details(account_id)
    rescue Provider::Gocardless::Error => e
      Rails.logger.warn("Failed to fetch account details for #{account_id}: #{e.message}")
      {}
    end

    def fetch_account_balances(account_id)
      gocardless_provider.get_account_balances(account_id)
    rescue Provider::Gocardless::Error => e
      Rails.logger.warn("Failed to fetch account balances for #{account_id}: #{e.message}")
      {}
    end

    def fetch_account_transactions(account_id)
      # GoCardless returns up to 90 days of transactions by default
      gocardless_provider.get_account_transactions(
        account_id,
        date_from: 90.days.ago.to_date
      )
    rescue Provider::Gocardless::Error => e
      Rails.logger.warn("Failed to fetch account transactions for #{account_id}: #{e.message}")
      {}
    end
end
