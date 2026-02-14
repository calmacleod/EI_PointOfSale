# frozen_string_literal: true

require "test_helper"

class DashboardMetricsTest < ActiveSupport::TestCase
  test "refresh! creates or updates records in database" do
    customers(:acme_corp).update_column(:created_at, 3.days.ago)
    customers(:jane_doe).update_column(:created_at, 10.days.ago)
    customers(:inactive_customer).update_column(:created_at, 10.days.ago)

    DashboardMetrics.refresh!

    record = DashboardMetric.find_by(key: "customers_last_7_days")
    assert record
    assert_equal 1, record.value.to_i
    assert_in_delta Time.current.to_f, record.computed_at.to_f, 5
  end

  test "[] returns value from database" do
    DashboardMetric.find_or_initialize_by(key: "customers_last_7_days").tap do |m|
      m.value = 42
      m.computed_at = Time.current
      m.save!
    end

    assert_equal 42, DashboardMetrics[:customers_last_7_days].to_i
  end

  test "[] computes on cache miss when definition exists" do
    customers(:acme_corp).update_column(:created_at, 2.days.ago)
    customers(:jane_doe).update_column(:created_at, 10.days.ago)
    customers(:inactive_customer).update_column(:created_at, 10.days.ago)

    assert_equal 1, DashboardMetrics[:customers_last_7_days].to_i
  end

  test "[] returns nil for unknown key" do
    assert_nil DashboardMetrics[:unknown_metric]
  end

  test "computed_at returns timestamp from record" do
    timestamp = 1.hour.ago
    DashboardMetric.find_or_initialize_by(key: "computed_at_test").tap do |m|
      m.value = 5
      m.computed_at = timestamp
      m.save!
    end

    assert_equal timestamp.to_i, DashboardMetrics.computed_at(:computed_at_test).to_i
  end

  test "customers_last_7_days excludes discarded" do
    customer = customers(:acme_corp)
    customer.update_column(:created_at, 3.days.ago)
    customers(:jane_doe).update_column(:created_at, 10.days.ago)
    customers(:inactive_customer).update_column(:created_at, 10.days.ago)

    DashboardMetrics.refresh!
    assert_equal 1, DashboardMetrics[:customers_last_7_days].to_i

    customer.discard
    DashboardMetrics.refresh!
    assert_equal 0, DashboardMetrics[:customers_last_7_days].to_i
  end
end
