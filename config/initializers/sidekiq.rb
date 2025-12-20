require "sidekiq/web"

# Configure Redis URL for Sidekiq (supports both local dev and Docker environments)
redis_url = ENV.fetch("REDIS_URL", "redis://localhost:6379/1")

Sidekiq.configure_server do |config|
  config.redis = { url: redis_url }

  # Start health check server for Kubernetes probes (worker mode only)
  config.on(:startup) do
    if defined?(RuntimeMode) && RuntimeMode.worker?
      require_relative "../../lib/sidekiq_health_check"
      SidekiqHealthCheck.start
    end
  end

  config.on(:shutdown) do
    if defined?(SidekiqHealthCheck)
      SidekiqHealthCheck.stop
    end
  end
end

Sidekiq.configure_client do |config|
  config.redis = { url: redis_url }
end

if Rails.env.production?
  Sidekiq::Web.use(Rack::Auth::Basic) do |username, password|
    configured_username = ::Digest::SHA256.hexdigest(ENV.fetch("SIDEKIQ_WEB_USERNAME", "perhaps"))
    configured_password = ::Digest::SHA256.hexdigest(ENV.fetch("SIDEKIQ_WEB_PASSWORD", "perhaps"))

    ActiveSupport::SecurityUtils.secure_compare(::Digest::SHA256.hexdigest(username), configured_username) &&
      ActiveSupport::SecurityUtils.secure_compare(::Digest::SHA256.hexdigest(password), configured_password)
  end
end

Sidekiq::Cron.configure do |config|
  # 10 min "catch-up" window in case worker process is re-deploying when cron tick occurs
  config.reschedule_grace_period = 600
end

# Only load cron schedule when running as a worker
# This prevents duplicate cron job scheduling across web and worker pods
if defined?(RuntimeMode) && RuntimeMode.worker?
  Rails.application.config.after_initialize do
    schedule_file = Rails.root.join("config/schedule.yml")
    if File.exist?(schedule_file)
      Sidekiq::Cron::Job.load_from_hash YAML.load_file(schedule_file)
      Rails.logger.info "[RuntimeMode] Loaded Sidekiq cron schedule"
    end
  end
elsif defined?(RuntimeMode) && !RuntimeMode.worker?
  Rails.logger.info "[RuntimeMode] Skipping Sidekiq cron schedule (not in worker mode)"
end
