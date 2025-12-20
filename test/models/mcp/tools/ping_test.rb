# frozen_string_literal: true

require "test_helper"

class Mcp::Tools::PingTest < ActiveSupport::TestCase
  setup do
    @family = families(:dylan_family)
    @server_context = { family: @family }
  end

  test "returns status ok with family info" do
    response = Mcp::Tools::Ping.call(server_context: @server_context)

    # Response is a MCP::Tool::Response with content array
    assert_instance_of ::MCP::Tool::Response, response
    assert response.content.is_a?(Array)
    assert_equal 1, response.content.length

    content_item = response.content.first
    assert content_item.is_a?(Hash)
    assert_equal "text", content_item[:type]

    result = JSON.parse(content_item[:text])
    assert_equal "ok", result["status"]
    assert_equal "perhaps-finance", result["server"]
    assert_equal "1.0.0", result["version"]
    assert_equal @family.id, result["family_id"]
    assert_equal @family.currency, result["family_currency"]
    assert result["timestamp"].present?
  end

  test "raises error when family is missing from context" do
    assert_raises(ArgumentError) do
      Mcp::Tools::Ping.call(server_context: {})
    end
  end
end
