class CreateGocardlessAccounts < ActiveRecord::Migration[7.2]
  def change
    create_table :gocardless_accounts, id: :uuid do |t|
      t.references :gocardless_item, null: false, foreign_key: true, type: :uuid
      t.string :gocardless_id, null: false
      t.string :iban
      t.string :name, null: false
      t.string :owner_name
      t.string :currency, null: false
      t.string :account_type
      t.decimal :current_balance, precision: 19, scale: 4
      t.decimal :available_balance, precision: 19, scale: 4
      t.jsonb :raw_payload, default: {}
      t.jsonb :raw_balances_payload, default: {}
      t.jsonb :raw_transactions_payload, default: {}
      t.timestamps
    end

    add_index :gocardless_accounts, :gocardless_id, unique: true
  end
end
