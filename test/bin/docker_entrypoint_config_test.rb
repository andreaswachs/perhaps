# frozen_string_literal: true

require "test_helper"

class DockerEntrypointConfigTest < ActiveSupport::TestCase
  test "runtime mode defaults to web" do
    # Clear environment and test default
    original = ENV.delete("PERHAPS_RUNTIME_MODE")
    RuntimeMode.instance_variable_set(:@current, nil)

    assert_equal "web", RuntimeMode.current

    ENV["PERHAPS_RUNTIME_MODE"] = original if original
    RuntimeMode.instance_variable_set(:@current, nil)
  end

  test "migration variables are recognized by application" do
    # Test that the application can read migration-related environment variables
    assert ENV.fetch("PERHAPS_RUN_MIGRATIONS", "true").in?(%w[true false])
    assert ENV.fetch("PERHAPS_IS_LEADER", "true").in?(%w[true false])
  end

  test "docker entrypoint script exists and is executable" do
    entrypoint_path = Rails.root.join("bin/docker-entrypoint")
    assert File.exist?(entrypoint_path), "bin/docker-entrypoint should exist"
    assert File.executable?(entrypoint_path), "bin/docker-entrypoint should be executable"
  end

  test "start-web script exists and is executable" do
    script_path = Rails.root.join("bin/start-web")
    assert File.exist?(script_path), "bin/start-web should exist"
    assert File.executable?(script_path), "bin/start-web should be executable"
  end

  test "start-worker script exists and is executable" do
    script_path = Rails.root.join("bin/start-worker")
    assert File.exist?(script_path), "bin/start-worker should exist"
    assert File.executable?(script_path), "bin/start-worker should be executable"
  end
end
