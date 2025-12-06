class GocardlessSyncJob < ApplicationJob
  queue_as :scheduled

  def perform
    return unless Provider::Registry.gocardless_provider.present?

    family_ids_with_gocardless = GocardlessItem.active.distinct.pluck(:family_id)

    Family.where(id: family_ids_with_gocardless).find_each do |family|
      family.gocardless_items.active.each do |gocardless_item|
        gocardless_item.sync_later
      rescue => e
        Rails.logger.error("Failed to schedule sync for GocardlessItem #{gocardless_item.id}: #{e.message}")
      end
    end
  end
end
