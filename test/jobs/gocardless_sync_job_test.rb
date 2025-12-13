require "test_helper"

class GocardlessSyncJobTest < ActiveJob::TestCase
  setup do
    @gocardless_provider = mock
  end

  test "syncs active gocardless items" do
    Provider::Registry.stubs(:gocardless_provider).returns(@gocardless_provider)

    # Count how many active items we have and expect that many calls
    active_count = GocardlessItem.active.count
    GocardlessItem.any_instance.expects(:sync_later).times(active_count)

    GocardlessSyncJob.perform_now
  end

  test "skips when gocardless provider not configured" do
    Provider::Registry.stubs(:gocardless_provider).returns(nil)

    GocardlessItem.any_instance.expects(:sync_later).never

    GocardlessSyncJob.perform_now
  end

  test "skips items scheduled for deletion" do
    Provider::Registry.stubs(:gocardless_provider).returns(@gocardless_provider)

    # Mark all items as scheduled for deletion
    GocardlessItem.update_all(scheduled_for_deletion: true)

    GocardlessItem.any_instance.expects(:sync_later).never

    GocardlessSyncJob.perform_now
  end

  test "continues syncing other items if one fails" do
    Provider::Registry.stubs(:gocardless_provider).returns(@gocardless_provider)

    # Mark all fixtures as scheduled for deletion (so they won't be synced)
    # instead of actually destroying them (which triggers callbacks)
    GocardlessItem.where.not(id: gocardless_items(:one).id).update_all(scheduled_for_deletion: true)

    # Create a second gocardless item
    family = families(:dylan_family)
    second_item = family.gocardless_items.create!(
      requisition_id: "req_second",
      institution_id: "BANK_2",
      name: "Second Bank",
      status: :linked
    )

    # First item raises error, second should still sync
    call_count = 0
    GocardlessItem.any_instance.stubs(:sync_later).with do
      call_count += 1
      if call_count == 1
        raise StandardError.new("API error")
      end
      true
    end

    # Should not raise
    GocardlessSyncJob.perform_now

    # Both items should have been attempted (2 calls total)
    assert_equal 2, call_count
  end
end
