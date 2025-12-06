class GocardlessItemsController < ApplicationController
  before_action :set_gocardless_item, only: %i[destroy sync edit reconnect]

  # Step 1: Show country selector
  def new
    @countries = Family::GocardlessConnectable::SUPPORTED_COUNTRIES
    @selected_country = params[:country] || Current.family.country&.upcase || "GB"
  end

  # Step 2: Show institution picker for selected country
  def select_country
    @country = params[:country]
    @institutions = Current.family.get_gocardless_institutions(country: @country)
  end

  # Step 3: Create requisition and redirect to GoCardless OAuth
  def create
    institution_id = gocardless_params[:institution_id]
    institution_name = gocardless_params[:institution_name]

    link_data = Current.family.create_gocardless_link(
      institution_id: institution_id,
      redirect_url: gocardless_callback_url
    )

    if link_data.nil?
      redirect_to accounts_path, alert: "Failed to create bank connection. Please try again."
      return
    end

    # Store requisition data in cache for callback (sessions are unreliable for cross-site redirects)
    cache_key = gocardless_cache_key(link_data[:reference])
    Rails.cache.write(cache_key, {
      requisition_id: link_data[:requisition_id],
      institution_id: institution_id,
      institution_name: institution_name,
      family_id: Current.family.id
    }, expires_in: 1.hour)

    redirect_to link_data[:link], allow_other_host: true
  end

  # Step 4: Handle OAuth callback from GoCardless
  def callback
    # Check for error from GoCardless
    if params[:error].present?
      redirect_to accounts_path, alert: "Bank connection failed: #{params[:error]}"
      return
    end

    # Get the reference from callback params
    reference = params[:ref]
    if reference.blank?
      redirect_to accounts_path, alert: "Invalid callback. Please try connecting your bank again."
      return
    end

    # Retrieve pending requisition data from cache
    cache_key = gocardless_cache_key(reference)
    pending = Rails.cache.read(cache_key)

    if pending.blank?
      redirect_to accounts_path, alert: "Session expired. Please try connecting your bank again."
      return
    end

    # Delete the cache entry after reading
    Rails.cache.delete(cache_key)

    # Verify the family matches
    if pending[:family_id] != Current.family.id
      redirect_to accounts_path, alert: "Invalid session. Please try connecting your bank again."
      return
    end

    # Check if this is a reconnection of an existing item
    if pending[:existing_item_id].present?
      existing_item = Current.family.gocardless_items.find_by(id: pending[:existing_item_id])
      if existing_item
        existing_item.update!(
          requisition_id: pending[:requisition_id],
          status: :linked,
          access_valid_until: 90.days.from_now
        )
        existing_item.sync_later
        redirect_to accounts_path, notice: "Bank reconnected successfully. Syncing your accounts now."
        return
      end
    end

    Current.family.create_gocardless_item!(
      requisition_id: pending[:requisition_id],
      institution_id: pending[:institution_id],
      institution_name: pending[:institution_name]
    )

    redirect_to accounts_path, notice: "Bank connected successfully. Your accounts will appear shortly."
  end

  # Show reconnect page for expired/suspended connections
  def edit
  end

  # Reconnect an expired/suspended connection
  def reconnect
    link_data = Current.family.create_gocardless_link(
      institution_id: @gocardless_item.institution_id,
      redirect_url: gocardless_callback_url
    )

    if link_data.nil?
      redirect_to accounts_path, alert: "Failed to reconnect bank. Please try again."
      return
    end

    # Store requisition data in cache for callback, including the existing item to update
    cache_key = gocardless_cache_key(link_data[:reference])
    Rails.cache.write(cache_key, {
      requisition_id: link_data[:requisition_id],
      institution_id: @gocardless_item.institution_id,
      institution_name: @gocardless_item.name,
      existing_item_id: @gocardless_item.id,
      family_id: Current.family.id
    }, expires_in: 1.hour)

    redirect_to link_data[:link], allow_other_host: true
  end

  def destroy
    @gocardless_item.destroy_later
    redirect_to accounts_path, notice: "Bank connection scheduled for removal."
  end

  def sync
    unless @gocardless_item.syncing?
      @gocardless_item.sync_later
    end

    respond_to do |format|
      format.html { redirect_back_or_to accounts_path }
      format.json { head :ok }
    end
  end

  private

  def set_gocardless_item
    @gocardless_item = Current.family.gocardless_items.find(params[:id])
  end

  def gocardless_params
    params.require(:gocardless_item).permit(:institution_id, :institution_name)
  end

  def gocardless_callback_url
    return callback_gocardless_items_url if Rails.env.production?

    ENV.fetch("DEV_CALLBACK_URL", root_url.chomp("/")) + "/gocardless_items/callback"
  end

  def gocardless_cache_key(reference)
    "gocardless_pending_requisition:#{reference}"
  end
end
