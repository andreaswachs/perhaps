require "test_helper"

class GocardlessItemsControllerTest < ActionDispatch::IntegrationTest
  setup do
    sign_in @user = users(:family_admin)
    @gocardless_provider = mock
    Provider::Registry.stubs(:gocardless_provider).returns(@gocardless_provider)
  end

  test "new shows country selector" do
    get new_gocardless_item_url

    assert_response :success
    assert_select "h2", "Connect European Bank"
  end

  test "select_country shows institutions" do
    @gocardless_provider.expects(:get_institutions).with(country: "GB").returns([
      { id: "BANK_1", name: "Test Bank", logo: nil }
    ])

    get select_country_gocardless_items_url(country: "GB")

    assert_response :success
  end

  test "create redirects to GoCardless OAuth" do
    @gocardless_provider.expects(:create_end_user_agreement)
      .with(institution_id: "BANK_1")
      .returns({ "id" => "agreement_123" })

    @gocardless_provider.expects(:create_requisition)
      .returns({
        "id" => "req_123",
        "link" => "https://ob.gocardless.com/psd2/start/req_123"
      })

    post gocardless_items_url, params: {
      gocardless_item: {
        institution_id: "BANK_1",
        institution_name: "Test Bank"
      }
    }

    assert_redirected_to "https://ob.gocardless.com/psd2/start/req_123"
    assert_equal "req_123", session[:pending_gocardless_requisition][:requisition_id]
  end

  test "callback creates gocardless item" do
    @gocardless_provider.expects(:get_requisition).with("req_123").returns({
      "id" => "req_123",
      "status" => "LN",
      "accounts" => ["acc_1"]
    })

    # Set up session
    session_data = {
      requisition_id: "req_123",
      institution_id: "BANK_1",
      institution_name: "Test Bank"
    }

    # We need to use a different approach since session isn't directly settable
    # Store in session via the create action first, then test callback
    assert_difference "GocardlessItem.count", 1 do
      get callback_gocardless_items_url,
        headers: { "rack.session" => { pending_gocardless_requisition: session_data } }
    end

    assert_redirected_to accounts_path
    assert_equal "Bank connected successfully. Your accounts will appear shortly.", flash[:notice]
  end

  test "callback handles missing session" do
    get callback_gocardless_items_url

    assert_redirected_to accounts_path
    assert_equal "Session expired. Please try connecting your bank again.", flash[:alert]
  end

  test "callback handles error param" do
    get callback_gocardless_items_url(error: "access_denied"),
      headers: { "rack.session" => { pending_gocardless_requisition: { requisition_id: "req_123" } } }

    assert_redirected_to accounts_path
    assert_equal "Bank connection failed: access_denied", flash[:alert]
  end

  test "destroy schedules deletion" do
    gocardless_item = gocardless_items(:one)

    delete gocardless_item_url(gocardless_item)

    assert_equal "Bank connection scheduled for removal.", flash[:notice]
    assert_enqueued_with job: DestroyJob
    assert_redirected_to accounts_path
  end

  test "sync triggers sync" do
    gocardless_item = gocardless_items(:one)
    GocardlessItem.any_instance.expects(:sync_later).once

    post sync_gocardless_item_url(gocardless_item)

    assert_redirected_to accounts_path
  end
end
