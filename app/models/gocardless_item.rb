class GocardlessItem < ApplicationRecord
  include Syncable, Provided

  enum :status, { pending: "pending", linked: "linked", expired: "expired", suspended: "suspended" }, default: :pending

  validates :name, :requisition_id, :institution_id, presence: true

  before_destroy :remove_gocardless_requisition

  belongs_to :family
  has_one_attached :logo

  has_many :gocardless_accounts, dependent: :destroy
  has_many :accounts, through: :gocardless_accounts

  scope :active, -> { where(scheduled_for_deletion: false) }
  scope :ordered, -> { order(created_at: :desc) }
  scope :needs_reauth, -> { where(status: %i[expired suspended]) }

  def access_expired?
    access_valid_until.present? && access_valid_until < Time.current
  end

  def access_expiring_soon?
    access_valid_until.present? && access_valid_until < 7.days.from_now
  end

  def destroy_later
    update!(scheduled_for_deletion: true)
    DestroyJob.perform_later(self)
  end

  def import_latest_gocardless_data
    GocardlessItem::Importer.new(self, gocardless_provider: gocardless_provider).import
  end

  def process_accounts
    gocardless_accounts.each do |gocardless_account|
      GocardlessAccount::Processor.new(gocardless_account).process
    end
  end

  def schedule_account_syncs(parent_sync: nil, window_start_date: nil, window_end_date: nil)
    accounts.each do |account|
      account.sync_later(
        parent_sync: parent_sync,
        window_start_date: window_start_date,
        window_end_date: window_end_date
      )
    end
  end

  def upsert_gocardless_snapshot!(requisition_snapshot)
    assign_attributes(
      status: map_status(requisition_snapshot["status"]),
      raw_payload: requisition_snapshot
    )

    save!
  end

  def upsert_gocardless_institution_snapshot!(institution_snapshot)
    assign_attributes(
      name: institution_snapshot["name"] || name,
      institution_logo_url: institution_snapshot["logo"],
      institution_country: institution_snapshot.dig("countries", 0),
      raw_institution_payload: institution_snapshot
    )

    save!
  end

  private

    def remove_gocardless_requisition
      gocardless_provider.delete_requisition(requisition_id)
    rescue Provider::Gocardless::Error => e
      # If requisition not found, it was already deleted - continue with local deletion
      raise e unless e.not_found?
    end

    def map_status(gocardless_status)
      case gocardless_status
      when "CR" then :pending
      when "LN" then :linked
      when "EX" then :expired
      when "SU" then :suspended
      when "RJ", "UA" then :expired
      else :pending
      end
    end
end
