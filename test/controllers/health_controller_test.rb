# frozen_string_literal: true

require "test_helper"

class HealthControllerTest < ActionDispatch::IntegrationTest
  test "sidekiq health endpoint returns JSON" do
    get health_sidekiq_path

    # Returns 200 if healthy or 503 if no processes running
    assert_includes [ 200, 503 ], response.status
    assert_equal "application/json", response.content_type.split(";").first

    body = JSON.parse(response.body)
    assert body.key?("healthy")
    assert body.key?("timestamp")
  end

  test "sidekiq health endpoint does not require authentication" do
    # Ensure no session or authentication headers
    get health_sidekiq_path

    # Should return 200 or 503, not 401/302
    assert_includes [ 200, 503 ], response.status
  end

  test "sidekiq health returns process and queue information" do
    get health_sidekiq_path

    body = JSON.parse(response.body)
    assert body.key?("processes")
    assert body.key?("queues")
    assert body.key?("stats")
  end
end
