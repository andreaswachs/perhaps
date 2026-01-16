class RemoveAiIntegrations < ActiveRecord::Migration[7.2]
  def up
    # Remove foreign key from users to chats first
    remove_foreign_key :users, :chats, column: :last_viewed_chat_id, if_exists: true

    # Remove AI-related columns from users table
    remove_column :users, :last_viewed_chat_id, :uuid, if_exists: true
    remove_column :users, :show_ai_sidebar, :boolean, if_exists: true
    remove_column :users, :ai_enabled, :boolean, if_exists: true

    # Drop AI-related tables (order matters due to foreign keys)
    drop_table :tool_calls, if_exists: true
    drop_table :messages, if_exists: true
    drop_table :chats, if_exists: true
  end

  def down
    # Recreate chats table
    create_table :chats, id: :uuid, default: -> { "gen_random_uuid()" } do |t|
      t.uuid :user_id, null: false
      t.string :title, null: false
      t.string :instructions
      t.jsonb :error
      t.string :latest_assistant_response_id
      t.timestamps
      t.index [:user_id]
    end

    # Recreate messages table
    create_table :messages, id: :uuid, default: -> { "gen_random_uuid()" } do |t|
      t.uuid :chat_id, null: false
      t.string :type, null: false
      t.string :status, default: "complete", null: false
      t.text :content
      t.string :ai_model
      t.timestamps
      t.boolean :debug, default: false
      t.string :provider_id
      t.boolean :reasoning, default: false
      t.index [:chat_id]
    end

    # Recreate tool_calls table
    create_table :tool_calls, id: :uuid, default: -> { "gen_random_uuid()" } do |t|
      t.uuid :message_id, null: false
      t.string :provider_id, null: false
      t.string :provider_call_id
      t.string :type, null: false
      t.string :function_name
      t.jsonb :function_arguments
      t.jsonb :function_result
      t.timestamps
      t.index [:message_id]
    end

    # Add AI-related columns back to users table
    add_column :users, :last_viewed_chat_id, :uuid
    add_column :users, :show_ai_sidebar, :boolean, default: true
    add_column :users, :ai_enabled, :boolean, default: false, null: false
    add_index :users, :last_viewed_chat_id

    # Add foreign keys
    add_foreign_key :chats, :users
    add_foreign_key :messages, :chats
    add_foreign_key :tool_calls, :messages
    add_foreign_key :users, :chats, column: :last_viewed_chat_id
  end
end
