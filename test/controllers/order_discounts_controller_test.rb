# frozen_string_literal: true

require "test_helper"

class OrderDiscountsControllerTest < ActionDispatch::IntegrationTest
  setup do
    @admin = users(:admin)
    sign_in_as(@admin)
    @order = orders(:draft_order)

    # Add a line item so discounts have something to apply to
    line = @order.order_lines.build(quantity: 2)
    line.snapshot_from_sellable!(products(:dragon_shield_red))
    line.position = 1
    line.save!
    Orders::CalculateTotals.call(@order)
    @order.reload
  end

  test "GET /orders/:id/order_discounts/new renders form" do
    get new_order_order_discount_path(@order)
    assert_response :success
  end

  test "POST /orders/:id/order_discounts creates a percentage discount" do
    assert_difference "OrderDiscount.count", 1 do
      post order_order_discounts_path(@order), params: {
        order_discount: { name: "Manual 5%", discount_type: "percentage", value: 5 }
      }, headers: TURBO_HEADERS
    end
    assert_response :success
  end

  test "POST creates a fixed_amount discount" do
    assert_difference "OrderDiscount.count", 1 do
      post order_order_discounts_path(@order), params: {
        order_discount: { name: "$3 Off", discount_type: "fixed_amount", value: 3 }
      }, headers: TURBO_HEADERS
    end
    assert_response :success
  end

  test "POST recalculates order totals after creating discount" do
    original_total = @order.total
    post order_order_discounts_path(@order), params: {
      order_discount: { name: "10% Off", discount_type: "percentage", value: 10 }
    }, headers: TURBO_HEADERS
    assert @order.reload.total < original_total
  end

  test "POST records a discount_applied event" do
    assert_difference "OrderEvent.count", 1 do
      post order_order_discounts_path(@order), params: {
        order_discount: { name: "VIP Discount", discount_type: "percentage", value: 15 }
      }, headers: TURBO_HEADERS
    end
    assert_equal "discount_applied", @order.order_events.last.event_type
  end

  test "POST returns turbo stream replacing order discount panels" do
    post order_order_discounts_path(@order), params: {
      order_discount: { name: "10% Off", discount_type: "percentage", value: 10 }
    }, headers: TURBO_HEADERS
    assert_response :success
    assert_turbo_stream_replaces(*ORDER_PANELS)
  end

  test "POST falls back to redirect when no Turbo headers" do
    post order_order_discounts_path(@order), params: {
      order_discount: { name: "10% Off", discount_type: "percentage", value: 10 }
    }
    assert_redirected_to edit_order_path(@order)
  end

  test "DELETE /order_discounts/:id removes the discount" do
    discount = @order.order_discounts.create!(
      name: "Test Discount", discount_type: :percentage, value: 10,
      scope: :all_items, applied_by: @admin
    )

    assert_difference "OrderDiscount.count", -1 do
      delete order_discount_path(discount), headers: TURBO_HEADERS
    end
    assert_response :success
  end

  test "DELETE recalculates totals after removing discount" do
    discount = @order.order_discounts.create!(
      name: "Test Discount", discount_type: :percentage, value: 10,
      scope: :all_items, applied_by: @admin
    )
    Orders::CalculateTotals.call(@order)
    @order.reload
    discounted_total = @order.total

    delete order_discount_path(discount), headers: TURBO_HEADERS

    assert @order.reload.total > discounted_total
  end

  test "DELETE records a discount_removed event" do
    discount = @order.order_discounts.create!(
      name: "Test Discount", discount_type: :percentage, value: 10,
      scope: :all_items, applied_by: @admin
    )

    assert_difference "OrderEvent.count", 1 do
      delete order_discount_path(discount), headers: TURBO_HEADERS
    end
    assert_equal "discount_removed", @order.order_events.last.event_type
  end

  test "DELETE returns turbo stream replacing order discount panels" do
    discount = @order.order_discounts.create!(
      name: "Test Discount", discount_type: :percentage, value: 10,
      scope: :all_items, applied_by: @admin
    )

    delete order_discount_path(discount), headers: TURBO_HEADERS
    assert_response :success
    assert_turbo_stream_replaces(*ORDER_PANELS)
  end
end
