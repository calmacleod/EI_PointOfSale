# frozen_string_literal: true

require "test_helper"

class OfflineControllerTest < ActionDispatch::IntegrationTest
  test "show is available without authentication and disables caching" do
    get offline_path

    assert_response :success
    assert_equal "no-store", response.headers["Cache-Control"]
    assert_includes response.body, "offline"
  end
end
