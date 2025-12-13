# GoCardless doesn't provide category information like Plaid does.
# This matcher attempts to categorize transactions based on the merchant/description text.
# It uses simple keyword matching against user-defined categories.
#
# Automated category matching in the Perhaps app has a hierarchy:
# 1. Naive string matching (this class)
# 2. Rules-based matching set by user
# 3. AI-powered matching (also enabled by user via rules)
class GocardlessAccount::Transactions::CategoryMatcher
  def initialize(user_categories = [])
    @user_categories = user_categories
  end

  # GoCardless doesn't provide categories, so we try to match based on transaction name
  def match(transaction_name)
    return nil unless transaction_name.present?

    normalized_name = normalize(transaction_name)

    # Try to find a category whose name appears in the transaction description
    user_categories.find do |category|
      normalized_category = normalize(category.name)
      normalized_name.include?(normalized_category) ||
        normalized_category.include?(normalized_name)
    end
  end

  private

    attr_reader :user_categories

    def normalize(str)
      str.to_s.downcase.gsub(/[^a-z0-9]/, " ").squish
    end
end
