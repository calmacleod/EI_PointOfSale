# frozen_string_literal: true

require "test_helper"

class RefreshDashboardMetricsJobTest < ActiveJob::TestCase
  test "perform refreshes dashboard metrics" do
    customers(:acme_corp).update_column(:created_at, 2.days.ago)
    customers(:jane_doe).update_column(:created_at, 10.days.ago)
    customers(:inactive_customer).update_column(:created_at, 10.days.ago)

    RefreshDashboardMetricsJob.perform_now

    record = DashboardMetric.find_by(key: "customers_last_7_days")
    assert record
    assert_equal 1, record.value.to_i
    assert_not_nil record.computed_at
  end
end
