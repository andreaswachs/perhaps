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
    assert_select "span.text-primary", "Connect European Bank"
  end

  test "select_country shows institutions" do
    @gocardless_provider.expects(:get_institutions).with(country: "GB").returns([
      { id: "BANK_1", name: "Test Bank", logo: nil }
    ])

    get select_country_gocardless_items_url(country: "GB")

    assert_response :success
  end

  test "create redirects to GoCardless OAuth" do
    reference = SecureRandom.uuid

    @gocardless_provider.expects(:create_end_user_agreement)
      .with(institution_id: "BANK_1")
      .returns({ "id" => "agreement_123" })

    @gocardless_provider.expects(:create_requisition)
      .returns({
        "id" => "req_123",
        "reference" => reference,
        "link" => "https://ob.gocardless.com/psd2/start/req_123"
      })

    post gocardless_items_url, params: {
      gocardless_item: {
        institution_id: "BANK_1",
        institution_name: "Test Bank"
      }
    }

    assert_redirected_to "https://ob.gocardless.com/psd2/start/req_123"
  end

  test "callback creates gocardless item" do
    reference = SecureRandom.uuid
    cache_key = "gocardless_pending_requisition:#{reference}"

    # Mock the cache read to return our pending data
    # (Test environment uses null_store so real caching doesn't work)
    pending_data = {
      requisition_id: "req_123",
      institution_id: "BANK_1",
      institution_name: "Test Bank",
      family_id: @user.family_id
    }

    Rails.cache.stubs(:read).with(cache_key).returns(pending_data)
    Rails.cache.stubs(:delete).with(cache_key)

    @gocardless_provider.expects(:get_requisition).with("req_123").returns({
      "id" => "req_123",
      "status" => "LN",
      "institution_id" => "BANK_1",
      "accounts" => [ "acc_1" ]
    })

    # Stub sync_later to avoid background job issues
    GocardlessItem.any_instance.stubs(:sync_later)

    assert_difference "GocardlessItem.count", 1 do
      get callback_gocardless_items_url(ref: reference)
    end

    assert_redirected_to accounts_path
    assert_equal "Bank connected successfully. Your accounts will appear shortly.", flash[:notice]
  end

  test "callback handles missing reference" do
    get callback_gocardless_items_url

    assert_redirected_to accounts_path
    assert_equal "Invalid callback. Please try connecting your bank again.", flash[:alert]
  end

  test "callback handles expired cache" do
    get callback_gocardless_items_url(ref: "nonexistent_ref")

    assert_redirected_to accounts_path
    assert_equal "Session expired. Please try connecting your bank again.", flash[:alert]
  end

  test "callback handles error param" do
    get callback_gocardless_items_url(error: "access_denied")

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
