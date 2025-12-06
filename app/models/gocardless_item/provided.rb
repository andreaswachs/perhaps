module GocardlessItem::Provided
  extend ActiveSupport::Concern

  def gocardless_provider
    @gocardless_provider ||= Provider::Registry.gocardless_provider
  end
end
