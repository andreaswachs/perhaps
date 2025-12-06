require "test_helper"

class Provider::GocardlessTest < ActiveSupport::TestCase
  setup do
    @gocardless = Provider::Gocardless.new(
      secret_id: "test_secret_id",
      secret_key: "test_secret_key"
    )
  end

  test "initializes with credentials" do
    assert_equal "test_secret_id", @gocardless.instance_variable_get(:@secret_id)
    assert_equal "test_secret_key", @gocardless.instance_variable_get(:@secret_key)
  end

  test "get_institutions returns institution list" do
    stub_request(:post, "https://bankaccountdata.gocardless.com/api/v2/token/new/")
      .to_return(status: 200, body: { access: "token", access_expires: 86400, refresh: "refresh", refresh_expires: 604800 }.to_json)

    stub_request(:get, "https://bankaccountdata.gocardless.com/api/v2/institutions/?country=GB")
      .to_return(status: 200, body: [
        { id: "SANDBOXFINANCE_SFIN0000", name: "Sandbox Finance", countries: ["GB"], logo: "https://example.com/logo.png" }
      ].to_json)

    institutions = @gocardless.get_institutions(country: "GB")

    assert_equal 1, institutions.size
    assert_equal "SANDBOXFINANCE_SFIN0000", institutions.first[:id]
    assert_equal "Sandbox Finance", institutions.first[:name]
  end

  test "create_end_user_agreement returns agreement" do
    stub_request(:post, "https://bankaccountdata.gocardless.com/api/v2/token/new/")
      .to_return(status: 200, body: { access: "token", access_expires: 86400, refresh: "refresh", refresh_expires: 604800 }.to_json)

    stub_request(:post, "https://bankaccountdata.gocardless.com/api/v2/agreements/enduser/")
      .to_return(status: 200, body: { id: "agreement_123", institution_id: "BANK_ID", max_historical_days: 90 }.to_json)

    agreement = @gocardless.create_end_user_agreement(institution_id: "BANK_ID")

    assert_equal "agreement_123", agreement["id"]
  end

  test "create_requisition returns requisition with link" do
    stub_request(:post, "https://bankaccountdata.gocardless.com/api/v2/token/new/")
      .to_return(status: 200, body: { access: "token", access_expires: 86400, refresh: "refresh", refresh_expires: 604800 }.to_json)

    stub_request(:post, "https://bankaccountdata.gocardless.com/api/v2/requisitions/")
      .to_return(status: 200, body: {
        id: "req_123",
        link: "https://ob.gocardless.com/psd2/start/req_123",
        status: "CR"
      }.to_json)

    requisition = @gocardless.create_requisition(
      institution_id: "BANK_ID",
      redirect_url: "https://example.com/callback",
      reference: "ref_123",
      agreement_id: "agreement_123"
    )

    assert_equal "req_123", requisition["id"]
    assert_includes requisition["link"], "gocardless.com"
  end

  test "get_requisition returns requisition details" do
    stub_request(:post, "https://bankaccountdata.gocardless.com/api/v2/token/new/")
      .to_return(status: 200, body: { access: "token", access_expires: 86400, refresh: "refresh", refresh_expires: 604800 }.to_json)

    stub_request(:get, "https://bankaccountdata.gocardless.com/api/v2/requisitions/req_123/")
      .to_return(status: 200, body: {
        id: "req_123",
        status: "LN",
        accounts: ["acc_1", "acc_2"]
      }.to_json)

    requisition = @gocardless.get_requisition("req_123")

    assert_equal "req_123", requisition["id"]
    assert_equal "LN", requisition["status"]
    assert_equal 2, requisition["accounts"].size
  end

  test "get_account_details returns account info" do
    stub_request(:post, "https://bankaccountdata.gocardless.com/api/v2/token/new/")
      .to_return(status: 200, body: { access: "token", access_expires: 86400, refresh: "refresh", refresh_expires: 604800 }.to_json)

    stub_request(:get, "https://bankaccountdata.gocardless.com/api/v2/accounts/acc_123/details/")
      .to_return(status: 200, body: {
        account: {
          iban: "GB33BUKB20201555555555",
          name: "Main Account",
          currency: "GBP"
        }
      }.to_json)

    details = @gocardless.get_account_details("acc_123")

    assert_equal "GB33BUKB20201555555555", details["account"]["iban"]
    assert_equal "GBP", details["account"]["currency"]
  end

  test "get_account_balances returns balance info" do
    stub_request(:post, "https://bankaccountdata.gocardless.com/api/v2/token/new/")
      .to_return(status: 200, body: { access: "token", access_expires: 86400, refresh: "refresh", refresh_expires: 604800 }.to_json)

    stub_request(:get, "https://bankaccountdata.gocardless.com/api/v2/accounts/acc_123/balances/")
      .to_return(status: 200, body: {
        balances: [
          { balanceAmount: { amount: "1500.50", currency: "GBP" }, balanceType: "expected" }
        ]
      }.to_json)

    balances = @gocardless.get_account_balances("acc_123")

    assert_equal 1, balances["balances"].size
    assert_equal "1500.50", balances["balances"].first["balanceAmount"]["amount"]
  end

  test "get_account_transactions returns transaction list" do
    stub_request(:post, "https://bankaccountdata.gocardless.com/api/v2/token/new/")
      .to_return(status: 200, body: { access: "token", access_expires: 86400, refresh: "refresh", refresh_expires: 604800 }.to_json)

    stub_request(:get, "https://bankaccountdata.gocardless.com/api/v2/accounts/acc_123/transactions/")
      .with(query: { date_from: "2024-01-01", date_to: "2024-01-31" })
      .to_return(status: 200, body: {
        transactions: {
          booked: [
            { transactionId: "txn_1", bookingDate: "2024-01-15", transactionAmount: { amount: "-50.00", currency: "GBP" } }
          ],
          pending: []
        }
      }.to_json)

    transactions = @gocardless.get_account_transactions("acc_123", date_from: "2024-01-01", date_to: "2024-01-31")

    assert_equal 1, transactions["transactions"]["booked"].size
    assert_equal "txn_1", transactions["transactions"]["booked"].first["transactionId"]
  end

  test "delete_requisition removes requisition" do
    stub_request(:post, "https://bankaccountdata.gocardless.com/api/v2/token/new/")
      .to_return(status: 200, body: { access: "token", access_expires: 86400, refresh: "refresh", refresh_expires: 604800 }.to_json)

    stub_request(:delete, "https://bankaccountdata.gocardless.com/api/v2/requisitions/req_123/")
      .to_return(status: 200, body: { summary: "Requisition deleted" }.to_json)

    response = @gocardless.delete_requisition("req_123")

    assert_equal "Requisition deleted", response["summary"]
  end

  test "raises error on API failure" do
    stub_request(:post, "https://bankaccountdata.gocardless.com/api/v2/token/new/")
      .to_return(status: 200, body: { access: "token", access_expires: 86400, refresh: "refresh", refresh_expires: 604800 }.to_json)

    stub_request(:get, "https://bankaccountdata.gocardless.com/api/v2/institutions/?country=XX")
      .to_return(status: 400, body: { detail: "Invalid country code" }.to_json)

    error = assert_raises(Provider::Gocardless::Error) do
      @gocardless.get_institutions(country: "XX")
    end

    assert_equal 400, error.status_code
    assert_includes error.message, "Invalid country code"
  end

  test "error not_found? returns true for 404" do
    error = Provider::Gocardless::Error.new("Not found", 404)
    assert error.not_found?
  end

  test "error not_found? returns false for other codes" do
    error = Provider::Gocardless::Error.new("Bad request", 400)
    assert_not error.not_found?
  end
end
