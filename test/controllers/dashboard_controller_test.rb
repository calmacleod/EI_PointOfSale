# frozen_string_literal: true

require "test_helper"

class DashboardControllerTest < ActionDispatch::IntegrationTest
  test "shows all metrics when user has no preferences" do
    user = users(:one)
    user.update_column(:dashboard_metric_keys, [])

    sign_in_as(user)
    get root_path

    assert_response :success
    assert_includes response.body, "New customers (7d)"
  end

  test "shows only selected metrics when user has preferences" do
    user = users(:one)
    user.update_column(:dashboard_metric_keys, [ "customers_last_7_days" ])

    sign_in_as(user)
    get root_path

    assert_response :success
    assert_includes response.body, "New customers (7d)"
  end
end
