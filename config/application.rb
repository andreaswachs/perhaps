require_relative "boot"

require "rails/all"

# Monkey patch to fix connection_pool 3.0 compatibility with Rails 7.2.3
# Must be loaded before cache store initialization which happens during Rails bootstrap.
# connection_pool 3.0 changed its API to require keyword arguments instead of a hash,
# but Rails 7.2.3's RedisCacheStore still passes a hash.
# This can be removed when upgrading to Rails 8.x which has the fix.
# See: https://github.com/rails/rails/pull/51613
require "connection_pool"
if Gem::Version.new(ConnectionPool::VERSION) >= Gem::Version.new("3.0")
  module RedisCacheStoreConnectionPoolPatch
    def initialize(error_handler: ActiveSupport::Cache::RedisCacheStore::DEFAULT_ERROR_HANDLER, **redis_options)
      universal_options = redis_options.extract!(*ActiveSupport::Cache::UNIVERSAL_OPTIONS)

      if pool_options = self.class.send(:retrieve_pool_options, redis_options)
        # Fix for connection_pool 3.0: use keyword arguments instead of hash
        @redis = ::ConnectionPool.new(**pool_options) { self.class.build_redis(**redis_options) }
      else
        @redis = self.class.build_redis(**redis_options)
      end

      @max_key_bytesize = ActiveSupport::Cache::RedisCacheStore::MAX_KEY_BYTESIZE
      @error_handler = error_handler

      # Call Store#initialize, skipping RedisCacheStore's initialize
      ActiveSupport::Cache::Store.instance_method(:initialize).bind(self).call(universal_options)
    end
  end

  ActiveSupport::Cache::RedisCacheStore.prepend(RedisCacheStoreConnectionPoolPatch)
end

# Require the gems listed in Gemfile, including any gems
# you've limited to :test, :development, or :production.
Bundler.require(*Rails.groups)

module Perhaps
  class Application < Rails::Application
    # Initialize configuration defaults for originally generated Rails version.
    config.load_defaults 7.2

    # Please, add to the `ignore` list any other `lib` subdirectories that do
    # not contain `.rb` files, or that should not be reloaded or eager loaded.
    # Common ones are `templates`, `generators`, or `middleware`, for example.
    config.autoload_lib(ignore: %w[assets tasks])

    # Configuration for the application, engines, and railties goes here.
    #
    # These settings can be overridden in specific environments using the files
    # in config/environments, which are processed later.
    #
    # config.time_zone = "Central Time (US & Canada)"
    # config.eager_load_paths << Rails.root.join("extras")

    # TODO: This is here for incremental adoption of localization.  This can be removed when all translations are implemented.
    config.i18n.fallbacks = true

    config.app_mode = (ENV["SELF_HOSTED"] == "true" || ENV["SELF_HOSTING_ENABLED"] == "true" ? "self_hosted" : "managed").inquiry

    # Self hosters can optionally set their own encryption keys if they want to use ActiveRecord encryption.
    begin
      if Rails.application.credentials.active_record_encryption.present?
        config.active_record.encryption = Rails.application.credentials.active_record_encryption
      end
    rescue ActiveSupport::EncryptedFile::MissingKeyError, ActiveSupport::EncryptedFile::MissingContentError, ArgumentError
      # Credentials file is optional in development
      Rails.logger&.warn("Credentials file not available or invalid - skipping encrypted configuration")
    end

    if Rails.env.development?
      config.lookbook.preview_display_options = {
        theme: [ "light", "dark" ] # available in view as params[:theme]
      }
    end

    # Enable Rack::Attack middleware for API rate limiting
    config.middleware.use Rack::Attack

    # Runtime mode helpers for Kubernetes deployments
    # These are loaded early, before initializers, so we read directly from ENV
    def self.runtime_mode
      ENV.fetch("PERHAPS_RUNTIME_MODE", "web").downcase.strip
    end

    def self.web_mode?
      %w[web all].include?(runtime_mode)
    end

    def self.worker_mode?
      %w[worker all].include?(runtime_mode)
    end
  end
end
