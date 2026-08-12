# frozen_string_literal: true

require "test_helper"

class PwaControllerTest < ActionDispatch::IntegrationTest
  test "service worker caches Vite assets and falls back to the native offline page" do
    get pwa_service_worker_path

    assert_response :success
    assert_includes response.body, 'const OFFLINE_FALLBACK_PATH = "/offline"'
    assert_includes response.body, "VITE_PATH_PATTERN"
    assert_includes response.body, "networkFirstNavigation"
    assert_not_includes response.body, "/offline/bundle.js"
  end
end
