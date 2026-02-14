# frozen_string_literal: true

require "test_helper"

class DashboardMetricTest < ActiveSupport::TestCase
  test "valid with key value and computed_at" do
    metric = DashboardMetric.new(key: "test_metric", value: 10, computed_at: Time.current)
    assert metric.valid?
  end

  test "invalid without key" do
    metric = DashboardMetric.new(value: 10, computed_at: Time.current)
    assert_not metric.valid?
    assert_includes metric.errors[:key], "can't be blank"
  end

  test "invalid without computed_at" do
    metric = DashboardMetric.new(key: "test", value: 10)
    assert_not metric.valid?
    assert_includes metric.errors[:computed_at], "can't be blank"
  end

  test "key must be unique" do
    DashboardMetric.create!(key: "dupe", value: 1, computed_at: Time.current)
    metric = DashboardMetric.new(key: "dupe", value: 2, computed_at: Time.current)
    assert_not metric.valid?
    assert_includes metric.errors[:key], "has already been taken"
  end
end
