class CreateGocardlessItems < ActiveRecord::Migration[7.2]
  def change
    create_table :gocardless_items, id: :uuid do |t|
      t.references :family, null: false, foreign_key: true, type: :uuid
      t.string :requisition_id, null: false
      t.string :institution_id, null: false
      t.string :name
      t.string :status, default: "pending", null: false
      t.datetime :access_valid_until
      t.string :institution_logo_url
      t.string :institution_country
      t.boolean :scheduled_for_deletion, default: false, null: false
      t.jsonb :raw_payload, default: {}
      t.jsonb :raw_institution_payload, default: {}
      t.timestamps
    end

    add_index :gocardless_items, :requisition_id, unique: true
    add_index :gocardless_items, [ :family_id, :status ]
  end
end
