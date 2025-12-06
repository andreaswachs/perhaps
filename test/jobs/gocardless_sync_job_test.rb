require "test_helper"

class GocardlessSyncJobTest < ActiveJob::TestCase
  setup do
    @gocardless_provider = mock
  end

  test "syncs active gocardless items" do
    Provider::Registry.stubs(:gocardless_provider).returns(@gocardless_provider)

    gocardless_item = gocardless_items(:one)
    GocardlessItem.any_instance.expects(:sync_later).once

    GocardlessSyncJob.perform_now
  end

  test "skips when gocardless provider not configured" do
    Provider::Registry.stubs(:gocardless_provider).returns(nil)

    GocardlessItem.any_instance.expects(:sync_later).never

    GocardlessSyncJob.perform_now
  end

  test "skips items scheduled for deletion" do
    Provider::Registry.stubs(:gocardless_provider).returns(@gocardless_provider)

    gocardless_item = gocardless_items(:one)
    gocardless_item.update!(scheduled_for_deletion: true)

    GocardlessItem.any_instance.expects(:sync_later).never

    GocardlessSyncJob.perform_now
  end

  test "continues syncing other items if one fails" do
    Provider::Registry.stubs(:gocardless_provider).returns(@gocardless_provider)

    # Create a second gocardless item
    family = families(:dylan_family)
    second_item = family.gocardless_items.create!(
      requisition_id: "req_second",
      institution_id: "BANK_2",
      name: "Second Bank",
      status: :linked
    )

    # First item raises error, second should still sync
    gocardless_items(:one).expects(:sync_later).raises(StandardError.new("API error"))
    second_item.expects(:sync_later).once

    # Should not raise
    GocardlessSyncJob.perform_now
  end
end
