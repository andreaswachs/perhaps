# frozen_string_literal: true

require "test_helper"

class RuntimeModeTest < ActiveSupport::TestCase
  setup do
    # Clear the cached mode before each test
    RuntimeMode.instance_variable_set(:@current, nil)
  end

  teardown do
    # Reset to default after each test
    ENV.delete("PERHAPS_RUNTIME_MODE")
    RuntimeMode.instance_variable_set(:@current, nil)
  end

  test "defaults to web mode when environment variable is not set" do
    ENV.delete("PERHAPS_RUNTIME_MODE")
    assert_equal "web", RuntimeMode.current
  end

  test "returns web mode when PERHAPS_RUNTIME_MODE is web" do
    ENV["PERHAPS_RUNTIME_MODE"] = "web"
    assert_equal "web", RuntimeMode.current
    assert RuntimeMode.web?
    assert_not RuntimeMode.worker?
    assert RuntimeMode.web_only?
    assert_not RuntimeMode.worker_only?
  end

  test "returns worker mode when PERHAPS_RUNTIME_MODE is worker" do
    ENV["PERHAPS_RUNTIME_MODE"] = "worker"
    assert_equal "worker", RuntimeMode.current
    assert_not RuntimeMode.web?
    assert RuntimeMode.worker?
    assert_not RuntimeMode.web_only?
    assert RuntimeMode.worker_only?
  end

  test "returns all mode when PERHAPS_RUNTIME_MODE is all" do
    ENV["PERHAPS_RUNTIME_MODE"] = "all"
    assert_equal "all", RuntimeMode.current
    assert RuntimeMode.web?
    assert RuntimeMode.worker?
    assert_not RuntimeMode.web_only?
    assert_not RuntimeMode.worker_only?
  end

  test "handles case insensitive mode values" do
    ENV["PERHAPS_RUNTIME_MODE"] = "WORKER"
    assert_equal "worker", RuntimeMode.current

    RuntimeMode.instance_variable_set(:@current, nil)
    ENV["PERHAPS_RUNTIME_MODE"] = "Web"
    assert_equal "web", RuntimeMode.current
  end

  test "handles whitespace in mode values" do
    ENV["PERHAPS_RUNTIME_MODE"] = "  worker  "
    assert_equal "worker", RuntimeMode.current
  end

  test "defaults to web mode for invalid values" do
    ENV["PERHAPS_RUNTIME_MODE"] = "invalid"
    assert_equal "web", RuntimeMode.current
  end
end
