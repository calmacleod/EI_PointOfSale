# frozen_string_literal: true

require "test_helper"

class Orders::CompleteTest < ActiveSupport::TestCase
  setup do
    @order = orders(:draft_order)
    @admin = users(:admin)
    @product = products(:dragon_shield_red)

    # Add a line item
    line = @order.order_lines.build(quantity: 2)
    line.snapshot_from_sellable!(@product)
    line.position = 1
    line.save!
    Orders::CalculateTotals.call(@order)
    @order.reload
  end

  test "completes order with sufficient payment" do
    @order.order_payments.create!(payment_method: :cash, amount: @order.total, amount_tendered: @order.total, received_by: @admin)

    initial_stock = @product.stock_level
    result = Orders::Complete.call(order: @order, actor: @admin)

    assert result.success?
    assert @order.reload.completed?
    assert_not_nil @order.completed_at
    assert_equal initial_stock - 2, @product.reload.stock_level
  end

  test "fails when payment is insufficient" do
    @order.order_payments.create!(payment_method: :cash, amount: 1.00, amount_tendered: 1.00, received_by: @admin)

    result = Orders::Complete.call(order: @order, actor: @admin)

    assert_not result.success?
    assert_includes result.errors.join, "Payment is incomplete"
    assert @order.reload.draft?
  end

  test "fails when order has no items" do
    empty_order = Order.create!(created_by: @admin, status: :draft)
    # No payment needed — order total is 0, and payment_complete? returns true,
    # but the "no items" check comes first.

    result = Orders::Complete.call(order: empty_order, actor: @admin)

    assert_not result.success?
    assert_includes result.errors.join, "no items"
  end

  test "fails when order is not in draft status" do
    completed = orders(:completed_order)

    result = Orders::Complete.call(order: completed, actor: @admin)

    assert_not result.success?
    assert_includes result.errors.join, "Only draft orders"
  end

  test "creates a completed event" do
    @order.order_payments.create!(payment_method: :cash, amount: @order.total, amount_tendered: @order.total, received_by: @admin)

    assert_difference "OrderEvent.count", 1 do
      Orders::Complete.call(order: @order, actor: @admin)
    end

    event = @order.order_events.last
    assert_equal "completed", event.event_type
    assert_equal @admin, event.actor
  end

  test "completes held order with discount after discount is removed" do
    # Apply the percentage discount to the order and calculate totals
    Discounts::AutoApply.call(@order)
    Orders::CalculateTotals.call(@order)
    @order.reload

    # Verify discount was applied
    assert @order.order_discounts.any?, "Discount should be applied"
    original_discount_total = @order.discount_total
    assert original_discount_total > 0, "Discount total should be greater than 0"

    # Hold the order
    Orders::Hold.call(order: @order, actor: @admin)
    assert @order.reload.held?

    # Remove the original discount from the system
    discount = discounts(:percentage_all)
    discount.destroy!

    # Resume and complete the order
    Orders::Resume.call(order: @order, actor: @admin)
    assert @order.reload.draft?

    # Payment should account for the discounted total
    discounted_total = @order.total
    @order.order_payments.create!(
      payment_method: :cash,
      amount: discounted_total,
      amount_tendered: discounted_total,
      received_by: @admin
    )

    result = Orders::Complete.call(order: @order, actor: @admin)

    assert result.success?, "Order should complete successfully"
    assert @order.reload.completed?
    # The discount should still be applied even though the original discount was removed
    assert_equal original_discount_total, @order.discount_total
    assert_equal discounted_total, @order.total
  end
end
