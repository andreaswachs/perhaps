module Account::Linkable
  extend ActiveSupport::Concern

  included do
    belongs_to :plaid_account, optional: true
    belongs_to :gocardless_account, optional: true
  end

  # A "linked" account gets transaction and balance data from a third party like Plaid or GoCardless
  def linked?
    plaid_account_id.present? || gocardless_account_id.present?
  end

  # Returns the name of the link provider, if any
  def link_provider
    return "plaid" if plaid_account_id.present?
    return "gocardless" if gocardless_account_id.present?
    nil
  end

  # An "offline" or "unlinked" account is one where the user tracks values and
  # adds transactions manually, without the help of a data provider
  def unlinked?
    !linked?
  end
  alias_method :manual?, :unlinked?
end
