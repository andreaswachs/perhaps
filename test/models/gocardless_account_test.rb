require "test_helper"

class GocardlessAccountTest < ActiveSupport::TestCase
  setup do
    @gocardless_account = gocardless_accounts(:one)
  end

  test "validates balance presence" do
    @gocardless_account.balance = nil
    assert_not @gocardless_account.valid?
    assert_includes @gocardless_account.errors[:balance], "can't be blank"
  end

  test "validates balance_date presence" do
    @gocardless_account.balance_date = nil
    assert_not @gocardless_account.valid?
    assert_includes @gocardless_account.errors[:balance_date], "can't be blank"
  end

  test "belongs to gocardless_item" do
    assert_equal gocardless_items(:one), @gocardless_account.gocardless_item
  end
end
