# Create OAuth applications for Perhaps's first-party apps
# These are the only OAuth apps that will exist - external developers use API keys

# Perhaps iOS App
ios_app = Doorkeeper::Application.find_or_create_by(name: "Perhaps iOS") do |app|
  app.redirect_uri = "perhaps://oauth/callback"
  # Use new OIDC scopes + data scopes
  app.scopes = "openid profile email read"
  app.confidential = false # Public client (mobile app)
end

puts "Created OAuth applications:"
puts "iOS App - Client ID: #{ios_app.uid}"
puts ""
puts "External developers should use API keys instead of OAuth."
