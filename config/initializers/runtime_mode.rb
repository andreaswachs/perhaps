# frozen_string_literal: true

# Runtime mode configuration for Kubernetes deployments
# Allows running Rails web server and Sidekiq workers in separate pods
#
# Environment variable: PERHAPS_RUNTIME_MODE
# Valid values:
#   - "web"    : Only Rails web server (default)
#   - "worker" : Only Sidekiq background workers
#   - "all"    : Both web server and Sidekiq (for simple deployments)
#
module RuntimeMode
  VALID_MODES = %w[web worker all].freeze
  DEFAULT_MODE = "web"

  class << self
    def current
      @current ||= fetch_mode
    end

    def web?
      current == "web" || current == "all"
    end

    def worker?
      current == "worker" || current == "all"
    end

    def web_only?
      current == "web"
    end

    def worker_only?
      current == "worker"
    end

    private

      def fetch_mode
        mode = ENV.fetch("PERHAPS_RUNTIME_MODE", DEFAULT_MODE).downcase.strip
        unless VALID_MODES.include?(mode)
          Rails.logger.warn "Invalid PERHAPS_RUNTIME_MODE '#{mode}', defaulting to '#{DEFAULT_MODE}'"
          mode = DEFAULT_MODE
        end
        mode
      end
  end
end

# Log the runtime mode on startup (helpful for debugging Kubernetes deployments)
Rails.application.config.after_initialize do
  Rails.logger.info "[RuntimeMode] Starting in '#{RuntimeMode.current}' mode"
  Rails.logger.info "[RuntimeMode] Web server: #{RuntimeMode.web? ? 'enabled' : 'disabled'}"
  Rails.logger.info "[RuntimeMode] Sidekiq workers: #{RuntimeMode.worker? ? 'enabled' : 'disabled'}"

  # Statelessness checks for multi-instance deployments
  if Rails.env.production?
    # Check cache store configuration
    cache_store = Rails.application.config.cache_store
    cache_store_type = cache_store.is_a?(Array) ? cache_store.first : cache_store
    unless cache_store_type == :redis_cache_store
      Rails.logger.warn "[Statelessness] Cache store is #{cache_store_type}. " \
        "For multi-instance deployments, set REDIS_URL or CACHE_REDIS_URL to enable Redis caching. " \
        "Rate limiting and OAuth flows may not work correctly across instances."
    end

    # Check Active Storage configuration
    storage_service = Rails.application.config.active_storage.service
    if storage_service == :local
      Rails.logger.warn "[Statelessness] Active Storage is using local disk storage. " \
        "For multi-instance deployments, set ACTIVE_STORAGE_SERVICE to 'amazon' or 'cloudflare' " \
        "to use cloud storage. File uploads will not be shared across instances."
    end
  end
end
