class GocardlessItem::SyncCompleteEvent
  attr_reader :gocardless_item

  def initialize(gocardless_item)
    @gocardless_item = gocardless_item
  end

  def broadcast
    gocardless_item.accounts.each do |account|
      account.broadcast_sync_complete
    end

    gocardless_item.broadcast_replace_to(
      gocardless_item.family,
      target: "gocardless_item_#{gocardless_item.id}",
      partial: "gocardless_items/gocardless_item",
      locals: { gocardless_item: gocardless_item }
    )

    gocardless_item.family.broadcast_sync_complete
  end
end
