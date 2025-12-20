class User < ApplicationRecord
  has_secure_password

  belongs_to :family
  belongs_to :last_viewed_chat, class_name: "Chat", optional: true
  has_many :sessions, dependent: :destroy
  has_many :chats, dependent: :destroy
  has_many :api_keys, dependent: :destroy
  has_many :mobile_devices, dependent: :destroy
  has_many :invitations, foreign_key: :inviter_id, dependent: :destroy
  has_many :impersonator_support_sessions, class_name: "ImpersonationSession", foreign_key: :impersonator_id, dependent: :destroy
  has_many :impersonated_support_sessions, class_name: "ImpersonationSession", foreign_key: :impersonated_id, dependent: :destroy
  accepts_nested_attributes_for :family, update_only: true

  validates :email, presence: true, uniqueness: true, format: { with: URI::MailTo::EMAIL_REGEXP }
  validate :ensure_valid_profile_image
  validates :default_period, inclusion: { in: Period::PERIODS.keys }
  normalizes :email, with: ->(email) { email.strip.downcase }
  normalizes :unconfirmed_email, with: ->(email) { email&.strip&.downcase }

  normalizes :first_name, :last_name, with: ->(value) { value.strip.presence }

  enum :role, { member: "member", admin: "admin", super_admin: "super_admin" }, validate: true

  has_one_attached :profile_image do |attachable|
    attachable.variant :thumbnail, resize_to_fill: [ 300, 300 ], convert: :webp, saver: { quality: 80 }
    attachable.variant :small, resize_to_fill: [ 72, 72 ], convert: :webp, saver: { quality: 80 }, preprocessed: true
  end

  validate :profile_image_size

  generates_token_for :password_reset, expires_in: 15.minutes do
    password_salt&.last(10)
  end

  generates_token_for :email_confirmation, expires_in: 1.day do
    unconfirmed_email
  end

  def pending_email_change?
    unconfirmed_email.present?
  end

  def initiate_email_change(new_email)
    return false if new_email == email
    return false if new_email == unconfirmed_email

    if Rails.application.config.app_mode.self_hosted? && !Setting.require_email_confirmation
      update(email: new_email)
    else
      if update(unconfirmed_email: new_email)
        EmailConfirmationMailer.with(user: self).confirmation_email.deliver_later
        true
      else
        false
      end
    end
  end

  def request_impersonation_for(user_id)
    impersonated = User.find(user_id)
    impersonator_support_sessions.create!(impersonated: impersonated)
  end

  def admin?
    super_admin? || role == "admin"
  end

  def display_name
    [ first_name, last_name ].compact.join(" ").presence || email
  end

  def initial
    (display_name&.first || email.first).upcase
  end

  def initials
    if first_name.present? && last_name.present?
      "#{first_name.first}#{last_name.first}".upcase
    else
      initial
    end
  end

  def show_ai_sidebar?
    show_ai_sidebar
  end

  def ai_available?
    !Rails.application.config.app_mode.self_hosted? || ENV["ANTHROPIC_API_KEY"].present?
  end

  def ai_enabled?
    ai_enabled && ai_available?
  end

  # Deactivation
  validate :can_deactivate, if: -> { active_changed? && !active }
  after_update_commit :purge_later, if: -> { saved_change_to_active?(from: true, to: false) }

  def deactivate
    update active: false, email: deactivated_email
  end

  def can_deactivate
    if admin? && family.users.count > 1
      errors.add(:base, :cannot_deactivate_admin_with_other_users)
    end
  end

  def purge_later
    UserPurgeJob.perform_later(self)
  end

  def purge
    if last_user_in_family?
      family.destroy
    else
      destroy
    end
  end

  # MFA
  def setup_mfa!
    update!(
      otp_secret: ROTP::Base32.random(32),
      otp_required: false,
      otp_backup_codes: []
    )
  end

  def enable_mfa!
    update!(
      otp_required: true,
      otp_backup_codes: generate_backup_codes
    )
  end

  def disable_mfa!
    update!(
      otp_secret: nil,
      otp_required: false,
      otp_backup_codes: []
    )
  end

  def verify_otp?(code)
    return false if otp_secret.blank?
    return true if verify_backup_code?(code)
    totp.verify(code, drift_behind: 15)
  end

  def provisioning_uri
    return nil unless otp_secret.present?
    totp.provisioning_uri(email)
  end

  def onboarded?
    onboarded_at.present?
  end

  def needs_onboarding?
    !onboarded?
  end

  # OIDC Claims for OpenID Connect token introspection
  # These methods provide standardized user information to OIDC clients

  # Standard OIDC 'sub' (subject) claim - unique identifier for the user
  def oidc_sub
    id.to_s
  end

  # Standard OIDC 'email' claim
  def oidc_email
    email
  end

  # Standard OIDC 'email_verified' claim
  def oidc_email_verified
    # Email is verified if there's no pending email change
    !pending_email_change?
  end

  # Standard OIDC 'name' claim - full display name
  def oidc_name
    display_name
  end

  # Standard OIDC 'given_name' claim
  def oidc_given_name
    first_name
  end

  # Standard OIDC 'family_name' claim
  def oidc_family_name
    last_name
  end

  # Custom claim: family_id for multi-tenancy
  # This allows MCP clients to scope data access to the correct family
  def oidc_family_id
    family_id
  end

  # Custom claim: user role within the family
  def oidc_role
    role
  end

  private
    def ensure_valid_profile_image
      return unless profile_image.attached?

      unless profile_image.content_type.in?(%w[image/jpeg image/png])
        errors.add(:profile_image, "must be a JPEG or PNG")
        profile_image.purge
      end
    end

    def last_user_in_family?
      family.users.count == 1
    end

    def deactivated_email
      email.gsub(/@/, "-deactivated-#{SecureRandom.uuid}@")
    end

    def profile_image_size
      if profile_image.attached? && profile_image.byte_size > 10.megabytes
        errors.add(:profile_image, :invalid_file_size, max_megabytes: 10)
      end
    end

    def totp
      ROTP::TOTP.new(otp_secret, issuer: "Perhaps Finance")
    end

    def verify_backup_code?(code)
      return false if otp_backup_codes.blank?

      # Find and remove the used backup code
      if (index = otp_backup_codes.index(code))
        remaining_codes = otp_backup_codes.dup
        remaining_codes.delete_at(index)
        update_column(:otp_backup_codes, remaining_codes)
        true
      else
        false
      end
    end

    def generate_backup_codes
      8.times.map { SecureRandom.hex(4) }
    end
end
