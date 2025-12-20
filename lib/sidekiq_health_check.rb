# frozen_string_literal: true

require "webrick"
require "json"

# Lightweight HTTP server for Sidekiq health checks
# Runs on a separate port (default: 7433) to provide /health endpoint
# Used by Kubernetes liveness and readiness probes for worker pods
#
# Usage:
#   SidekiqHealthCheck.start(port: 7433)
#   SidekiqHealthCheck.stop
#
module SidekiqHealthCheck
  class << self
    attr_reader :server, :thread

    def start(port: default_port)
      return if @server

      @server = WEBrick::HTTPServer.new(
        Port: port,
        Logger: WEBrick::Log.new("/dev/null"),
        AccessLog: []
      )

      @server.mount_proc "/health" do |_req, res|
        health_status = check_health
        res.status = health_status[:healthy] ? 200 : 503
        res.content_type = "application/json"
        res.body = health_status.to_json
      end

      @server.mount_proc "/ready" do |_req, res|
        ready_status = check_readiness
        res.status = ready_status[:ready] ? 200 : 503
        res.content_type = "application/json"
        res.body = ready_status.to_json
      end

      @thread = Thread.new { @server.start }
      Rails.logger.info "[SidekiqHealthCheck] Started health check server on port #{port}"
    end

    def stop
      return unless @server

      @server.shutdown
      @thread&.join(5)
      @server = nil
      @thread = nil
      Rails.logger.info "[SidekiqHealthCheck] Stopped health check server"
    end

    def default_port
      ENV.fetch("SIDEKIQ_HEALTH_PORT", 7433).to_i
    end

    private

      def check_health
        # Check if Sidekiq process is running and connected to Redis
        begin
          redis_connected = Sidekiq.redis { |conn| conn.ping == "PONG" }
          process_set = Sidekiq::ProcessSet.new
          process_running = process_set.any? { |p| p["pid"] == Process.pid }

          {
            healthy: redis_connected,
            redis: redis_connected ? "connected" : "disconnected",
            process_registered: process_running,
            pid: Process.pid,
            timestamp: Time.current.iso8601
          }
        rescue => e
          {
            healthy: false,
            error: e.message,
            pid: Process.pid,
            timestamp: Time.current.iso8601
          }
        end
      end

      def check_readiness
        # Check if Sidekiq is ready to process jobs
        begin
          redis_connected = Sidekiq.redis { |conn| conn.ping == "PONG" }
          queues = Sidekiq::Queue.all.map { |q| { name: q.name, size: q.size } }

          {
            ready: redis_connected,
            redis: redis_connected ? "connected" : "disconnected",
            queues: queues,
            pid: Process.pid,
            timestamp: Time.current.iso8601
          }
        rescue => e
          {
            ready: false,
            error: e.message,
            pid: Process.pid,
            timestamp: Time.current.iso8601
          }
        end
      end
  end
end
