class AddGocardlessAccountIdToAccounts < ActiveRecord::Migration[7.2]
  def change
    add_reference :accounts, :gocardless_account, type: :uuid, foreign_key: true, index: true
  end
end
