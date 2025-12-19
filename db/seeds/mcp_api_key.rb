# Create API key for MCP server access during development
# This allows local LLMs to access the MCP server with minimal setup

if Rails.env.development?
  # Find the demo user (created by demo_data:default rake task)
  demo_user = User.find_by(email: "user@perhaps.local")

  if demo_user
    # Check if an API key already exists for this user
    existing_key = demo_user.api_keys.active.where(source: "web", name: "MCP Development Key").first

    unless existing_key
      # Generate a predictable API key for development
      api_key_value = "pk_dev_mcp_test_key_12345678901234567890123456789012"

      api_key = demo_user.api_keys.create!(
        name: "MCP Development Key",
        key: api_key_value,
        scopes: [ "read" ],
        source: "web"
      )

      puts "Created MCP API Key for demo user:"
      puts "  API Key: #{api_key.plain_key}"
      puts "  User: #{demo_user.email}"
      puts "  Scopes: #{api_key.scopes.join(', ')}"
      puts ""
      puts "Use this API key to access the MCP server at:"
      puts "  POST http://localhost:3000/api/v1/mcp"
      puts "  Header: X-Api-Key: #{api_key.plain_key}"
    else
      puts "MCP API Key already exists for demo user:"
      puts "  API Key: #{existing_key.plain_key}"
      puts "  User: #{demo_user.email}"
    end
  else
    puts "Demo user not found. Run 'rake demo_data:default' first to create demo data."
  end
end
