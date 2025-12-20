# frozen_string_literal: true

require "test_helper"
require "sidekiq_health_check"
require "net/http"

class SidekiqHealthCheckTest < ActiveSupport::TestCase
  setup do
    @port = find_available_port
  end

  teardown do
    SidekiqHealthCheck.stop
    sleep 0.2 # Give the port time to release
  end

  private

    def find_available_port
      # Find an available port by binding and unbinding
      server = TCPServer.new("127.0.0.1", 0)
      port = server.addr[1]
      server.close
      port
    end

    test "starts and stops health check server" do
      SidekiqHealthCheck.start(port: @port)
      assert SidekiqHealthCheck.server.present?
      assert SidekiqHealthCheck.thread.present?
      assert SidekiqHealthCheck.thread.alive?

      SidekiqHealthCheck.stop
      assert_nil SidekiqHealthCheck.server
    end

    test "health endpoint returns JSON response" do
      SidekiqHealthCheck.start(port: @port)
      sleep 0.1 # Give server time to start

      uri = URI("http://localhost:#{@port}/health")
      response = Net::HTTP.get_response(uri)

      assert_includes [ 200, 503 ], response.code.to_i
      assert_equal "application/json", response.content_type

      body = JSON.parse(response.body)
      assert body.key?("healthy")
      assert body.key?("pid")
      assert body.key?("timestamp")
    end

    test "ready endpoint returns JSON response" do
      SidekiqHealthCheck.start(port: @port)
      sleep 0.1 # Give server time to start

      uri = URI("http://localhost:#{@port}/ready")
      response = Net::HTTP.get_response(uri)

      assert_includes [ 200, 503 ], response.code.to_i
      assert_equal "application/json", response.content_type

      body = JSON.parse(response.body)
      assert body.key?("ready")
      assert body.key?("pid")
      assert body.key?("timestamp")
    end

    test "default_port returns from environment variable" do
      original_port = ENV["SIDEKIQ_HEALTH_PORT"]

      ENV["SIDEKIQ_HEALTH_PORT"] = "8888"
      assert_equal 8888, SidekiqHealthCheck.default_port

      ENV["SIDEKIQ_HEALTH_PORT"] = original_port
    end

    test "default_port returns 7433 when environment variable not set" do
      original_port = ENV.delete("SIDEKIQ_HEALTH_PORT")
      assert_equal 7433, SidekiqHealthCheck.default_port
      ENV["SIDEKIQ_HEALTH_PORT"] = original_port if original_port
    end
end
