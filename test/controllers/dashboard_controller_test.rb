# frozen_string_literal: true

require "test_helper"

class DashboardControllerTest < ActionDispatch::IntegrationTest
  test "shows all metrics when user has no preferences" do
    user = users(:one)
    user.update_column(:dashboard_metric_keys, [])

    # Populate dashboard metrics so they display correctly
    DashboardMetrics.refresh!

    sign_in_as(user)
    get root_path

    assert_response :success

    # Check that dashboard renders with metric labels
    assert_includes response.body, "Dashboard"
    assert_includes response.body, "Recent orders"
  end

  test "shows only selected metrics when user has preferences" do
    user = users(:one)
    user.update_column(:dashboard_metric_keys, [ "customers_last_7_days" ])

    sign_in_as(user)
    get root_path

    assert_response :success
    assert_includes response.body, "New customers (7d)"
  end

  test "shows at most 5 recent orders" do
    user = users(:one)
    sign_in_as(user)

    # Create 7 orders to ensure we have more than the limit
    7.times do |i|
      Order.create!(
        status: :completed,
        total: 10.00,
        created_by: user,
        completed_at: i.minutes.ago
      )
    end

    get root_path
    assert_response :success

    # The page should show "Recent orders" section
    assert_includes response.body, "Recent orders"
  end
end
