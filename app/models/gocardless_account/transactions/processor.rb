class GocardlessAccount::Transactions::Processor
  def initialize(gocardless_account)
    @gocardless_account = gocardless_account
  end

  def process
    # Each entry is processed inside a transaction, but to avoid locking up the DB when
    # there are hundreds or thousands of transactions, we process them individually.
    booked_transactions.each do |transaction|
      GocardlessEntry::Processor.new(
        transaction,
        gocardless_account: gocardless_account,
        category_matcher: category_matcher
      ).process
    end
  end

  private

    attr_reader :gocardless_account

    def category_matcher
      @category_matcher ||= GocardlessAccount::Transactions::CategoryMatcher.new(family_categories)
    end

    def family_categories
      @family_categories ||= begin
        if account.family.categories.none?
          account.family.categories.bootstrap!
        end

        account.family.categories
      end
    end

    def account
      gocardless_account.account
    end

    # GoCardless separates booked (confirmed) from pending transactions
    # We only process booked transactions as they are finalized
    def booked_transactions
      gocardless_account.raw_transactions_payload.dig("transactions", "booked") || []
    end
end
