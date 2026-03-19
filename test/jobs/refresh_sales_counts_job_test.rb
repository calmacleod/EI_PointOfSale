# frozen_string_literal: true

require "test_helper"

class RefreshSalesCountsJobTest < ActiveJob::TestCase
  test "completed orders increment sales_count" do
    RefreshSalesCountsJob.perform_now

    product = products(:dragon_shield_red)
    product.reload
    assert_equal 2, product.sales_count, "Expected sales_count to match completed order line quantity"
  end

  test "draft and held orders are excluded" do
    # dragon_shield_red has a held_line (qty 1) and completed_line_one (qty 2)
    # Only the completed order should count
    RefreshSalesCountsJob.perform_now

    product = products(:dragon_shield_red)
    product.reload
    assert_equal 2, product.sales_count
  end

  test "orders older than 90 days are excluded" do
    orders(:completed_order).update_column(:completed_at, 91.days.ago)

    RefreshSalesCountsJob.perform_now

    product = products(:dragon_shield_red)
    product.reload
    assert_equal 0, product.sales_count
  end

  test "items with no recent sales are zeroed out" do
    products(:dragon_shield_blue).update_column(:sales_count, 50)

    RefreshSalesCountsJob.perform_now

    assert_equal 0, products(:dragon_shield_blue).reload.sales_count
  end
end
