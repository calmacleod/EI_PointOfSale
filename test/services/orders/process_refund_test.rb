# frozen_string_literal: true

require "test_helper"

class Orders::ProcessRefundTest < ActiveSupport::TestCase
  setup do
    @order = orders(:completed_order)
    @admin = users(:admin)
    @line = order_lines(:completed_line_one)
  end

  test "processes a full refund" do
    line_params = [
      { order_line_id: @line.id, quantity: @line.quantity, restock: true }
    ]

    result = Orders::ProcessRefund.call(order: @order, actor: @admin, line_params: line_params, reason: "Defective")

    assert result.success?
    assert_equal "full", result.refund.refund_type
    assert @order.reload.refunded?
  end

  test "processes a partial refund" do
    line_params = [
      { order_line_id: @line.id, quantity: 1, restock: true }
    ]

    result = Orders::ProcessRefund.call(order: @order, actor: @admin, line_params: line_params, reason: "Partial return")

    assert result.success?
    assert_equal "partial", result.refund.refund_type
    assert @order.reload.partially_refunded?
  end

  test "restocks products when restock is true" do
    product = @line.sellable
    initial_stock = product.stock_level

    line_params = [
      { order_line_id: @line.id, quantity: 1, restock: true }
    ]

    Orders::ProcessRefund.call(order: @order, actor: @admin, line_params: line_params)
    assert_equal initial_stock + 1, product.reload.stock_level
  end

  test "does not restock when restock is false" do
    product = @line.sellable
    initial_stock = product.stock_level

    line_params = [
      { order_line_id: @line.id, quantity: 1, restock: false }
    ]

    Orders::ProcessRefund.call(order: @order, actor: @admin, line_params: line_params)
    assert_equal initial_stock, product.reload.stock_level
  end

  test "fails for non-completed orders" do
    draft = orders(:draft_order)

    result = Orders::ProcessRefund.call(order: draft, actor: @admin, line_params: [ { order_line_id: 1, quantity: 1 } ])

    assert_not result.success?
    assert_includes result.errors.join, "Only completed orders"
  end

  test "records a refund event" do
    line_params = [
      { order_line_id: @line.id, quantity: 1, restock: false }
    ]

    assert_difference "OrderEvent.count", 1 do
      Orders::ProcessRefund.call(order: @order, actor: @admin, line_params: line_params)
    end
  end
end
