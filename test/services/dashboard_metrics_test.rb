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

  test "todays_sales computes correctly" do
    user = users(:one)

    # Create completed orders for today
    Order.create!(status: :completed, total: 100.00, created_by: user, completed_at: Time.current)
    Order.create!(status: :completed, total: 50.00, created_by: user, completed_at: Time.current)

    # Create order from yesterday (should not count)
    Order.create!(status: :completed, total: 200.00, created_by: user, completed_at: 1.day.ago)

    DashboardMetrics.refresh!

    assert_in_delta 150.00, DashboardMetrics[:todays_sales].to_f, 0.01
  end

  test "todays_transactions counts completed orders today" do
    user = users(:one)

    Order.create!(status: :completed, total: 10.00, created_by: user, completed_at: Time.current)
    Order.create!(status: :completed, total: 20.00, created_by: user, completed_at: Time.current)
    Order.create!(status: :draft, total: 30.00, created_by: user, created_at: Time.current)
    Order.create!(status: :completed, total: 40.00, created_by: user, completed_at: 1.day.ago)

    DashboardMetrics.refresh!

    assert_equal 2, DashboardMetrics[:todays_transactions].to_i
  end

  test "average_ticket_today calculates correctly" do
    user = users(:one)

    Order.create!(status: :completed, total: 100.00, created_by: user, completed_at: Time.current)
    Order.create!(status: :completed, total: 50.00, created_by: user, completed_at: Time.current)

    DashboardMetrics.refresh!

    assert_in_delta 75.00, DashboardMetrics[:average_ticket_today].to_f, 0.01
  end

  test "average_ticket_today returns zero when no transactions" do
    DashboardMetrics.refresh!
    assert_equal 0.0, DashboardMetrics[:average_ticket_today].to_f
  end

  test "low_stock_items counts products below reorder level" do
    product = products(:dragon_shield_red)
    product.update!(stock_level: 5, reorder_level: 10)

    # Product with stock above reorder level
    products(:dragon_shield_blue).update!(stock_level: 20, reorder_level: 10)

    # Product with reorder_level of 0 (should not count)
    products(:nhl_puck).update!(stock_level: 0, reorder_level: 0)

    DashboardMetrics.refresh!

    assert DashboardMetrics[:low_stock_items].to_i >= 1
  end

  test "low_stock_items excludes discarded products" do
    product = products(:dragon_shield_red)
    product.update!(stock_level: 5, reorder_level: 10)

    DashboardMetrics.refresh!
    initial_count = DashboardMetrics[:low_stock_items].to_i

    product.discard
    DashboardMetrics.refresh!

    assert_equal initial_count - 1, DashboardMetrics[:low_stock_items].to_i
  end
end
