require "test_helper"

class GocardlessItemTest < ActiveSupport::TestCase
  include SyncableInterfaceTest

  setup do
    @gocardless_item = @syncable = gocardless_items(:one)
    @gocardless_provider = mock
    Provider::Registry.stubs(:gocardless_provider).returns(@gocardless_provider)
  end

  test "removes gocardless requisition when destroyed" do
    @gocardless_provider.expects(:delete_requisition).with(@gocardless_item.requisition_id).once

    assert_difference "GocardlessItem.count", -1 do
      @gocardless_item.destroy
    end
  end

  test "continues destruction if requisition not found" do
    error = Provider::Gocardless::Error.new("Not found", 404)
    @gocardless_provider.expects(:delete_requisition).raises(error)

    assert_difference "GocardlessItem.count", -1 do
      @gocardless_item.destroy
    end
  end

  test "access_expired? returns true when access_valid_until is in the past" do
    @gocardless_item.update!(access_valid_until: 1.day.ago)
    assert @gocardless_item.access_expired?
  end

  test "access_expired? returns false when access_valid_until is in the future" do
    @gocardless_item.update!(access_valid_until: 1.day.from_now)
    assert_not @gocardless_item.access_expired?
  end

  test "access_expiring_soon? returns true when within 7 days" do
    @gocardless_item.update!(access_valid_until: 5.days.from_now)
    assert @gocardless_item.access_expiring_soon?
  end

  test "access_expiring_soon? returns false when more than 7 days away" do
    @gocardless_item.update!(access_valid_until: 10.days.from_now)
    assert_not @gocardless_item.access_expiring_soon?
  end

  test "destroy_later schedules deletion" do
    assert_enqueued_with job: DestroyJob do
      @gocardless_item.destroy_later
    end

    assert @gocardless_item.reload.scheduled_for_deletion?
  end

  test "maps GoCardless status correctly" do
    statuses = {
      "CR" => "pending",
      "LN" => "linked",
      "EX" => "expired",
      "SU" => "suspended",
      "RJ" => "expired",
      "UA" => "expired"
    }

    statuses.each do |gc_status, expected_status|
      @gocardless_item.upsert_gocardless_snapshot!({ "status" => gc_status })
      assert_equal expected_status, @gocardless_item.status
    end
  end

  test "active scope excludes scheduled_for_deletion items" do
    @gocardless_item.update!(scheduled_for_deletion: true)
    assert_not_includes GocardlessItem.active, @gocardless_item
  end

  test "needs_reauth scope returns expired and suspended items" do
    expired = gocardless_items(:expired)
    assert_includes GocardlessItem.needs_reauth, expired
    assert_not_includes GocardlessItem.needs_reauth, @gocardless_item
  end
end
