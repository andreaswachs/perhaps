module GocardlessAccount::TypeMappable
  extend ActiveSupport::Concern

  UnknownAccountTypeError = Class.new(StandardError)

  def map_accountable(account_type)
    accountable_class = TYPE_MAPPING.dig(
      account_type&.to_sym,
      :accountable
    ) || TYPE_MAPPING[:CACC][:accountable] # Default to Depository

    accountable_class.new
  end

  def map_subtype(account_type)
    TYPE_MAPPING.dig(
      account_type&.to_sym,
      :subtype
    ) || "other"
  end

  # GoCardless Account Types -> Accountable Types
  # https://nordigen.com/en/docs/account-information/output/accounts/
  # Cash account types follow ISO 20022 ExternalCashAccountType1Code
  TYPE_MAPPING = {
    CACC: { accountable: Depository, subtype: "checking" },      # Current/Checking Account
    SVGS: { accountable: Depository, subtype: "savings" },       # Savings Account
    TRAN: { accountable: Depository, subtype: "checking" },      # Transaction Account
    CASH: { accountable: Depository, subtype: "checking" },      # Cash Account
    CARD: { accountable: CreditCard, subtype: "credit_card" },   # Card Account
    LOAN: { accountable: Loan, subtype: "other" },               # Loan Account
    MORT: { accountable: Loan, subtype: "mortgage" },            # Mortgage Account
    OTHR: { accountable: OtherAsset, subtype: "other" }          # Other
  }.freeze
end
