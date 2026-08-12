# frozen_string_literal: true

require "test_helper"

class OfflineControllerTest < ActionDispatch::IntegrationTest
  test "show requires authentication" do
    get offline_path

    assert_response :redirect
  end

  test "show renders the native Inertia offline lookup and disables HTTP caching" do
    sign_in_as(users(:one))

    get offline_path

    assert_response :success
    assert_equal "no-store", response.headers["Cache-Control"]
    assert_equal "offline", inertia_props["view"]
    assert_equal root_path, inertia_props["home_path"]
    assert_equal api_v1_products_sync_path, inertia_props.dig("sync_paths", "products")
    assert_equal api_v1_services_sync_path, inertia_props.dig("sync_paths", "services")
    assert_equal api_v1_customers_sync_path, inertia_props.dig("sync_paths", "customers")
    assert_equal api_v1_tax_codes_sync_path, inertia_props.dig("sync_paths", "tax_codes")
  end
end
