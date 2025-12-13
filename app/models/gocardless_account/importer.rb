class GocardlessAccount::Importer
  def initialize(gocardless_account, account_snapshot:)
    @gocardless_account = gocardless_account
    @account_snapshot = account_snapshot
  end

  def import
    import_account_info
    import_balances if account_snapshot.balances_data.present?
    import_transactions if account_snapshot.transactions_data.present?
  end

  private

    attr_reader :gocardless_account, :account_snapshot

    def import_account_info
      gocardless_account.upsert_gocardless_snapshot!(account_snapshot.account_data)
    end

    def import_balances
      gocardless_account.upsert_gocardless_balances_snapshot!(account_snapshot.balances_data)
    end

    def import_transactions
      gocardless_account.upsert_gocardless_transactions_snapshot!(account_snapshot.transactions_data)
    end
end
