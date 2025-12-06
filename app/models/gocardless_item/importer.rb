class GocardlessItem::Importer
  def initialize(gocardless_item, gocardless_provider:)
    @gocardless_item = gocardless_item
    @gocardless_provider = gocardless_provider
  end

  def import
    fetch_and_import_requisition_data
    fetch_and_import_accounts_data
  rescue Provider::Gocardless::Error => e
    handle_gocardless_error(e)
  end

  private

  attr_reader :gocardless_item, :gocardless_provider

  def handle_gocardless_error(error)
    if error.access_expired?
      gocardless_item.update!(status: :expired)
    elsif error.requires_reauthentication?
      gocardless_item.update!(status: :suspended)
    else
      raise error
    end
  end

  def fetch_and_import_requisition_data
    requisition_data = gocardless_provider.get_requisition(gocardless_item.requisition_id)
    institution_data = gocardless_provider.get_institution(gocardless_item.institution_id)

    gocardless_item.upsert_gocardless_snapshot!(requisition_data)
    gocardless_item.upsert_gocardless_institution_snapshot!(institution_data)
  end

  def fetch_and_import_accounts_data
    snapshot = GocardlessItem::AccountsSnapshot.new(gocardless_item, gocardless_provider: gocardless_provider)

    GocardlessItem.transaction do
      snapshot.accounts.each do |account_id|
        gocardless_account = gocardless_item.gocardless_accounts.find_or_initialize_by(
          gocardless_id: account_id
        )

        GocardlessAccount::Importer.new(
          gocardless_account,
          account_snapshot: snapshot.get_account_data(account_id)
        ).import
      end
    end
  end
end
