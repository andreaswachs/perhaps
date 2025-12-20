# frozen_string_literal: true

class HealthController < ApplicationController
  skip_before_action :authenticate_user!, raise: false
  skip_before_action :set_current_user, raise: false
  skip_before_action :verify_authenticity_token, raise: false

  # GET /health/sidekiq
  # Returns Sidekiq health status for monitoring dashboards
  # Note: This runs on the web server, not the worker.
  # For worker pod probes, use the dedicated SidekiqHealthCheck server.
  def sidekiq
    status = sidekiq_status
    render json: status, status: status[:healthy] ? :ok : :service_unavailable
  end

  private

    def sidekiq_status
      redis_connected = Sidekiq.redis { |conn| conn.ping == "PONG" }
      process_set = Sidekiq::ProcessSet.new
      processes = process_set.map do |process|
        {
          hostname: process["hostname"],
          pid: process["pid"],
          started_at: Time.at(process["started_at"]).iso8601,
          queues: process["queues"],
          concurrency: process["concurrency"],
          busy: process["busy"]
        }
      end

      queues = Sidekiq::Queue.all.map { |q| { name: q.name, size: q.size, latency: q.latency.round(2) } }
      stats = Sidekiq::Stats.new

      {
        healthy: redis_connected && processes.any?,
        redis: redis_connected ? "connected" : "disconnected",
        processes: processes,
        process_count: processes.size,
        queues: queues,
        stats: {
          processed: stats.processed,
          failed: stats.failed,
          scheduled_size: stats.scheduled_size,
          retry_size: stats.retry_size,
          dead_size: stats.dead_size,
          enqueued: stats.enqueued
        },
        timestamp: Time.current.iso8601
      }
    rescue => e
      {
        healthy: false,
        error: e.message,
        timestamp: Time.current.iso8601
      }
    end
end
