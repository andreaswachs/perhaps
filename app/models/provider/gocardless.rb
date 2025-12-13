class Provider::Gocardless
  BASE_URL = "https://bankaccountdata.gocardless.com/api/v2"
  MAX_TRANSACTION_DAYS = 90

  class Error < StandardError
    attr_reader :code, :details

    def initialize(message, code: nil, details: nil)
      super(message)
      @code = code
      @details = details
    end

    def not_found?
      code == "NOT_FOUND" || code == 404
    end

    def access_expired?
      %w[EUA_EXPIRED CR_EXPIRED].include?(code)
    end

    def requires_reauthentication?
      %w[ACCESS_INVALID ITEM_LOGIN_REQUIRED].include?(code) || access_expired?
    end
  end

  def initialize(secret_id:, secret_key:)
    @secret_id = secret_id
    @secret_key = secret_key
    @access_token = nil
    @token_expires_at = nil
  end

  # Get list of supported institutions for a country
  def get_institutions(country:)
    with_authentication do
      response = connection.get("institutions/") do |req|
        req.params["country"] = country
      end

      handle_response(response)
    end
  end

  # Get single institution details
  def get_institution(institution_id)
    with_authentication do
      response = connection.get("institutions/#{institution_id}/")
      handle_response(response)
    end
  end

  # Create an end user agreement (defines access scope and validity)
  def create_end_user_agreement(institution_id:, max_historical_days: MAX_TRANSACTION_DAYS, access_valid_for_days: 90)
    with_authentication do
      response = connection.post("agreements/enduser/") do |req|
        req.body = {
          institution_id: institution_id,
          max_historical_days: max_historical_days,
          access_valid_for_days: access_valid_for_days,
          access_scope: %w[balances details transactions]
        }
      end

      handle_response(response)
    end
  end

  # Create a requisition (bank connection request)
  def create_requisition(institution_id:, redirect_url:, reference:, agreement_id: nil)
    with_authentication do
      body = {
        institution_id: institution_id,
        redirect: redirect_url,
        reference: reference,
        user_language: "EN"
      }
      body[:agreement] = agreement_id if agreement_id.present?

      response = connection.post("requisitions/") do |req|
        req.body = body
      end

      handle_response(response)
    end
  end

  # Get requisition status and linked accounts
  def get_requisition(requisition_id)
    with_authentication do
      response = connection.get("requisitions/#{requisition_id}/")
      handle_response(response)
    end
  end

  # Delete a requisition
  def delete_requisition(requisition_id)
    with_authentication do
      response = connection.delete("requisitions/#{requisition_id}/")
      handle_response(response)
    end
  end

  # Get account metadata
  def get_account(account_id)
    with_authentication do
      response = connection.get("accounts/#{account_id}/")
      handle_response(response)
    end
  end

  # Get account details (IBAN, owner name, etc.)
  def get_account_details(account_id)
    with_authentication do
      response = connection.get("accounts/#{account_id}/details/")
      data = handle_response(response)
      data["account"] || data
    end
  end

  # Get account balances
  def get_account_balances(account_id)
    with_authentication do
      response = connection.get("accounts/#{account_id}/balances/")
      handle_response(response)
    end
  end

  # Get account transactions
  def get_account_transactions(account_id, date_from: nil, date_to: nil)
    with_authentication do
      params = {}
      params[:date_from] = date_from.to_s if date_from.present?
      params[:date_to] = date_to.to_s if date_to.present?

      response = connection.get("accounts/#{account_id}/transactions/") do |req|
        req.params = params if params.present?
      end

      handle_response(response)
    end
  end

  private

    attr_reader :secret_id, :secret_key

    def connection
      @connection ||= Faraday.new(url: BASE_URL) do |f|
        f.request :json
        f.response :json
        f.adapter Faraday.default_adapter
      end
    end

    def with_authentication
      authenticate! if token_expired?

      connection.headers["Authorization"] = "Bearer #{@access_token}"

      yield
    end

    def authenticate!
      response = Faraday.post("#{BASE_URL}/token/new/") do |req|
        req.headers["Content-Type"] = "application/json"
        req.body = { secret_id: secret_id, secret_key: secret_key }.to_json
      end

      if response.success?
        data = JSON.parse(response.body)
        @access_token = data["access"]
        @token_expires_at = Time.current + data["access_expires"].to_i.seconds
      else
        error_data = begin
          JSON.parse(response.body)
        rescue
          { "detail" => response.body }
        end
        raise Error.new(
          "GoCardless authentication failed: #{error_data['detail'] || response.status}",
          code: "AUTH_FAILED",
          details: error_data
        )
      end
    end

    def token_expired?
      @access_token.nil? || @token_expires_at.nil? || @token_expires_at < Time.current
    end

    def handle_response(response)
      case response.status
      when 200..299
        response.body
      when 401
        raise Error.new("Authentication failed", code: "AUTH_FAILED", details: response.body)
      when 404
        raise Error.new("Resource not found", code: "NOT_FOUND", details: response.body)
      when 409
        error_detail = extract_error_detail(response.body)
        raise Error.new(
          "Conflict: #{error_detail}",
          code: response.body.dig("type") || "CONFLICT",
          details: response.body
        )
      else
        error_detail = extract_error_detail(response.body)
        error_code = response.body.is_a?(Hash) ? (response.body["type"] || response.body["code"]) : nil

        raise Error.new(
          "GoCardless API error (#{response.status}): #{error_detail}",
          code: error_code || response.status,
          details: response.body
        )
      end
    end

    def extract_error_detail(body)
      return body unless body.is_a?(Hash)
      body["detail"] || body["summary"] || body["message"] || body.to_s
    end
end
