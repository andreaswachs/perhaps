class RemoveAiChatsAndFeatures < ActiveRecord::Migration[7.2]
  def change
    # Remove user columns related to AI chat (must do before dropping chats table due to FK)
    remove_reference :users, :last_viewed_chat, foreign_key: { to_table: :chats }, type: :uuid
    remove_column :users, :show_ai_sidebar, :boolean, default: true
    remove_column :users, :ai_enabled, :boolean, default: false, null: false

    # Drop tables in correct order (dependencies first)
    drop_table :tool_calls, id: :uuid do |t|
      t.references :message, null: false, foreign_key: true, type: :uuid
      t.string :provider_id, null: false
      t.string :provider_call_id
      t.string :type, null: false
      t.string :function_name
      t.jsonb :function_arguments
      t.jsonb :function_result
      t.timestamps
    end

    drop_table :messages, id: :uuid do |t|
      t.references :chat, null: false, foreign_key: true, type: :uuid
      t.string :type, null: false
      t.string :status, null: false, default: "complete"
      t.text :content
      t.string :ai_model
      t.boolean :debug, default: false
      t.string :provider_id
      t.boolean :reasoning, default: false
      t.timestamps
    end

    drop_table :chats, id: :uuid do |t|
      t.references :user, null: false, foreign_key: true, type: :uuid
      t.string :title, null: false
      t.string :instructions
      t.jsonb :error
      t.string :latest_assistant_response_id
      t.timestamps
    end
  end
end
