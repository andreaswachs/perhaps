module Family::GocardlessConnectable
  extend ActiveSupport::Concern

  SUPPORTED_COUNTRIES = %w[
    AT BE BG CY CZ DE DK EE ES FI FR GB GR HR HU IE IT LT LU LV MT NL NO PL PT RO SE SI SK
  ].freeze

  included do
    has_many :gocardless_items, dependent: :destroy
  end

  def gocardless_enabled?
    gocardless_provider.present?
  end

  def can_connect_gocardless?
    gocardless_enabled? && gocardless_supported_country?
  end

  def gocardless_supported_country?
    SUPPORTED_COUNTRIES.include?(country.to_s.upcase)
  end

  def get_gocardless_institutions(country:)
    return [] unless gocardless_provider

    gocardless_provider.get_institutions(country: country)
  rescue Provider::Gocardless::Error => e
    Rails.logger.error("Failed to fetch GoCardless institutions: #{e.message}")
    []
  end

  def create_gocardless_link(institution_id:, redirect_url:)
    return nil unless gocardless_provider

    # Create end user agreement first (defines access scope and validity)
    agreement = gocardless_provider.create_end_user_agreement(institution_id: institution_id)

    # Generate reference for callback identification
    reference = "perhaps_#{id}_#{Time.current.to_i}"

    # Create requisition with the agreement
    requisition = gocardless_provider.create_requisition(
      institution_id: institution_id,
      redirect_url: redirect_url,
      reference: reference,
      agreement_id: agreement["id"]
    )

    {
      link: requisition["link"],
      requisition_id: requisition["id"],
      agreement_id: agreement["id"],
      reference: reference
    }
  end

  def create_gocardless_item!(requisition_id:, institution_id:, institution_name:)
    # Fetch requisition to get access validity info
    begin
      requisition = gocardless_provider.get_requisition(requisition_id)
    rescue Provider::Gocardless::Error => e
      Rails.logger.error("Failed to fetch GoCardless requisition #{requisition_id}: #{e.message}")
      # Continue creating the item even if we can't fetch the requisition
      # The sync job will handle any issues
      requisition = nil
    end

    gocardless_item = gocardless_items.create!(
      requisition_id: requisition_id,
      institution_id: institution_id,
      name: institution_name,
      status: :linked,
      access_valid_until: 90.days.from_now
    )

    gocardless_item.sync_later

    gocardless_item
  end

  private

    def gocardless_provider
      Provider::Registry.gocardless_provider
    end
end
