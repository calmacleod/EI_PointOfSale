# frozen_string_literal: true

require "test_helper"

class OrderDiscountOverridesControllerTest < ActionDispatch::IntegrationTest
  setup do
    @admin = users(:admin)
    sign_in_as(@admin)
    @order = orders(:draft_order)

    # Add a line item
    @line = @order.order_lines.build(quantity: 1)
    @line.snapshot_from_sellable!(products(:dragon_shield_red))
    @line.position = 1
    @line.save!
    Orders::CalculateTotals.call(@order)
    @order.reload
  end

  test "DELETE /orders/:id/order_discount_overrides/:id restores excluded line discounts" do
    source = discounts(:percentage_all)
    discount = @line.order_line_discounts.create!(
      name: "10% Off", discount_type: :percentage, value: 10,
      calculated_amount: 1.50, excluded_quantity: 0, auto_applied: true,
      source_discount: source, excluded_at: 1.hour.ago
    )

    delete order_order_discount_override_path(@order, source.id), headers: TURBO_HEADERS
    assert_response :success
    assert_nil discount.reload.excluded_at
  end

  test "DELETE recalculates totals" do
    delete order_order_discount_override_path(@order, discounts(:percentage_all).id), headers: TURBO_HEADERS
    assert_response :success
  end

  test "DELETE returns turbo stream replacing order panels" do
    delete order_order_discount_override_path(@order, discounts(:percentage_all).id), headers: TURBO_HEADERS
    assert_response :success
    assert_turbo_stream_replaces(*ORDER_PANELS)
  end

  test "DELETE falls back to redirect when no Turbo headers" do
    delete order_order_discount_override_path(@order, discounts(:percentage_all).id)
    assert_redirected_to edit_order_path(@order)
  end

  test "requires authentication" do
    delete session_path
    delete order_order_discount_override_path(@order, discounts(:percentage_all).id), headers: TURBO_HEADERS
    assert_redirected_to new_session_path
  end
end
