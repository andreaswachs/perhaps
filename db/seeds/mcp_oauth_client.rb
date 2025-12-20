# frozen_string_literal: true

# Create a generic OAuth application for MCP (Model Context Protocol) clients
# This application is used by LLM clients like Claude Desktop, ChatGPT, etc.
# to authenticate users and access their financial data through the MCP server.

# Find or create the MCP OAuth application
mcp_app = Doorkeeper::Application.find_or_initialize_by(name: "MCP Client")

# Configure the application
mcp_app.assign_attributes(
  # Redirect URIs for common MCP clients
  # These follow the OAuth 2.0 spec for native applications
  redirect_uri: [
    # Claude Desktop (Anthropic)
    "claude://oauth/callback",
    "http://localhost:8080/callback",
    # Generic local development callback
    "http://localhost:3000/oauth/callback",
    # For testing with tools like Postman or curl
    "urn:ietf:wg:oauth:2.0:oob"
  ].join("\n"),

  # OIDC + data access scopes
  # MCP clients need OIDC scopes for authentication AND data scopes for API access
  scopes: "openid profile email read read_write",

  # Public client (native application)
  # MCP clients run on user devices and cannot securely store client secrets
  # PKCE (Proof Key for Code Exchange) is required for security
  confidential: false
)

if mcp_app.save
  puts "MCP OAuth Application configured:"
  puts "  Name: #{mcp_app.name}"
  puts "  Client ID: #{mcp_app.uid}"
  puts "  Client Secret: (not needed for public clients)"
  puts "  Redirect URIs:"
  mcp_app.redirect_uri.split("\n").each do |uri|
    puts "    - #{uri}"
  end
  puts "  Scopes: #{mcp_app.scopes}"
  puts "  Confidential: #{mcp_app.confidential}"
  puts ""
  puts "MCP clients can now authenticate users using this OAuth application."
  puts "Authorization URL: http://localhost:3000/oauth/authorize?client_id=#{mcp_app.uid}&redirect_uri=claude://oauth/callback&response_type=code&scope=openid+profile+email+read"
else
  puts "Failed to create MCP OAuth Application:"
  mcp_app.errors.full_messages.each do |error|
    puts "  - #{error}"
  end
end
