require "test_helper"

class GocardlessAccountTest < ActiveSupport::TestCase
  setup do
    @gocardless_account = gocardless_accounts(:one)
  end

  test "validates name presence" do
    @gocardless_account.name = nil
    assert_not @gocardless_account.valid?
    assert_includes @gocardless_account.errors[:name], "can't be blank"
  end

  test "validates currency presence" do
    @gocardless_account.currency = nil
    assert_not @gocardless_account.valid?
    assert_includes @gocardless_account.errors[:currency], "can't be blank"
  end

  test "belongs to gocardless_item" do
    assert_equal gocardless_items(:one), @gocardless_account.gocardless_item
  end
end
