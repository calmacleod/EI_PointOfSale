# frozen_string_literal: true

require "test_helper"

class UserDashboardMetricsTest < ActiveSupport::TestCase
  test "visible_dashboard_metric_keys returns all when blank" do
    user = users(:one)
    user.update_column(:dashboard_metric_keys, [])

    assert_equal DashboardMetrics.available_keys, user.visible_dashboard_metric_keys
  end

  test "visible_dashboard_metric_keys returns subset when set" do
    user = users(:one)
    user.update_column(:dashboard_metric_keys, [ "customers_last_7_days" ])

    assert_equal [ "customers_last_7_days" ], user.visible_dashboard_metric_keys
  end

  test "visible_dashboard_metric_keys filters invalid keys" do
    user = users(:one)
    user.update_column(:dashboard_metric_keys, [ "customers_last_7_days", "invalid_key" ])

    assert_equal [ "customers_last_7_days" ], user.visible_dashboard_metric_keys
  end

  test "dashboard_metric_keys_for_form returns all when blank" do
    user = users(:one)
    user.update_column(:dashboard_metric_keys, [])

    assert_equal DashboardMetrics.available_keys, user.dashboard_metric_keys_for_form
  end

  test "dashboard_metric_keys_for_form returns stored keys when set" do
    user = users(:one)
    user.update_column(:dashboard_metric_keys, [ "customers_last_7_days" ])

    assert_equal [ "customers_last_7_days" ], user.dashboard_metric_keys_for_form
  end
end
