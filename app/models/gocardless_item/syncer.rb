class GocardlessItem::Syncer
  attr_reader :gocardless_item

  def initialize(gocardless_item)
    @gocardless_item = gocardless_item
  end

  def perform_sync(sync)
    # Loads requisition metadata, accounts, transactions, and balances to DB
    gocardless_item.import_latest_gocardless_data

    # Processes the raw GoCardless data and updates internal domain objects
    gocardless_item.process_accounts

    # All data is synced, so we can now run an account sync to calculate historical balances
    gocardless_item.schedule_account_syncs(
      parent_sync: sync,
      window_start_date: sync.window_start_date,
      window_end_date: sync.window_end_date
    )
  end

  def perform_post_sync
    # No-op for now, but could be used to send notifications about expiring access
  end
end
