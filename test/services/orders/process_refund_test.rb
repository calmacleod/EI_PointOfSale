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

  test "prorates order discounts across full and cumulative partial refunds" do
    @order.update_column(:status, Order.statuses[:draft])
    other_line = @order.order_lines.build(quantity: 1, position: 2)
    other_line.snapshot_from_sellable!(products(:nhl_puck))
    other_line.save!

    @order.order_discounts.create!(
      name: "Fixed order discount",
      discount_type: :fixed_amount,
      value: 2.01,
      scope: :all_items,
      applied_by: @admin
    )
    Orders::CalculateTotals.call(@order)
    @order.update_column(:status, Order.statuses[:completed])
    order_total = @order.reload.total

    first = Orders::ProcessRefund.call(
      order: @order,
      actor: @admin,
      line_params: [ { order_line_id: @line.id, quantity: 1, restock: false } ]
    )
    assert first.success?, first.errors.join(", ")
    assert_equal 16.14, first.refund.total

    final = Orders::ProcessRefund.call(
      order: @order.reload,
      actor: @admin,
      line_params: [
        { order_line_id: @line.id, quantity: 1, restock: false },
        { order_line_id: other_line.id, quantity: 1, restock: false }
      ]
    )

    assert final.success?, final.errors.join(", ")
    assert_equal 24.76, final.refund.total
    assert_equal order_total, @order.refunds.sum(:total)
    assert_equal order_total, first.refund.total + final.refund.total
  end

  test "full refund with an order discount equals the order total" do
    @order.update_column(:status, Order.statuses[:draft])
    other_line = @order.order_lines.build(quantity: 1, position: 2)
    other_line.snapshot_from_sellable!(products(:nhl_puck))
    other_line.save!
    @order.order_discounts.create!(
      name: "Fixed order discount",
      discount_type: :fixed_amount,
      value: 2.01,
      scope: :all_items,
      applied_by: @admin
    )
    Orders::CalculateTotals.call(@order)
    @order.update_column(:status, Order.statuses[:completed])
    order_total = @order.reload.total

    result = Orders::ProcessRefund.call(
      order: @order,
      actor: @admin,
      line_params: [
        { order_line_id: @line.id, quantity: @line.quantity, restock: false },
        { order_line_id: other_line.id, quantity: other_line.quantity, restock: false }
      ]
    )

    assert result.success?, result.errors.join(", ")
    assert_equal order_total, result.refund.total
    assert_equal order_total, @order.reload.refunds.sum(:total)
  end

  test "rejects a refund that would exceed the order total after a prior over-refund" do
    @order.update_column(:status, Order.statuses[:draft])
    other_line = @order.order_lines.build(quantity: 1, position: 2)
    other_line.snapshot_from_sellable!(products(:nhl_puck))
    other_line.save!
    @order.order_discounts.create!(
      name: "Fixed order discount",
      discount_type: :fixed_amount,
      value: 2.01,
      scope: :all_items,
      applied_by: @admin
    )
    Orders::CalculateTotals.call(@order)
    @order.update_column(:status, Order.statuses[:completed])
    @order.reload

    # Simulate a partial refund recorded before order discounts were prorated.
    previous = @order.refunds.create!(refund_type: :partial, total: 16.94, processed_by: @admin)
    previous.refund_lines.create!(order_line: @line, quantity: 1, amount: 16.94, restock: false)
    @order.update_column(:status, Order.statuses[:partially_refunded])

    assert_no_difference "Refund.count" do
      result = Orders::ProcessRefund.call(
        order: @order.reload,
        actor: @admin,
        line_params: [
          { order_line_id: @line.id, quantity: 1, restock: false },
          { order_line_id: other_line.id, quantity: 1, restock: false }
        ]
      )

      assert_not result.success?
      assert_includes result.errors.join, "Refund exceeds remaining refundable order total"
    end
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

  test "fails when refund quantity is zero" do
    result = Orders::ProcessRefund.call(
      order: @order,
      actor: @admin,
      line_params: [ { order_line_id: @line.id, quantity: 0, restock: false } ]
    )

    assert_not result.success?
    assert_includes result.errors.join, "must be greater than 0"
    assert_no_difference "Refund.count" do
      Orders::ProcessRefund.call(order: @order, actor: @admin, line_params: [ { order_line_id: @line.id, quantity: 0 } ])
    end
  end

  test "fails when refund quantity exceeds sold quantity" do
    result = Orders::ProcessRefund.call(
      order: @order,
      actor: @admin,
      line_params: [ { order_line_id: @line.id, quantity: @line.quantity + 1, restock: false } ]
    )

    assert_not result.success?
    assert_includes result.errors.join, "exceeds remaining refundable quantity"
  end

  test "fails when cumulative partial refunds exceed sold quantity" do
    first = Orders::ProcessRefund.call(
      order: @order,
      actor: @admin,
      line_params: [ { order_line_id: @line.id, quantity: 1, restock: false } ]
    )

    assert first.success?

    second = Orders::ProcessRefund.call(
      order: @order.reload,
      actor: @admin,
      line_params: [ { order_line_id: @line.id, quantity: @line.quantity, restock: false } ]
    )

    assert_not second.success?
    assert_includes second.errors.join, "exceeds remaining refundable quantity"
  end

  test "marks order fully refunded when final partial refund exhausts all quantities" do
    first = Orders::ProcessRefund.call(
      order: @order,
      actor: @admin,
      line_params: [ { order_line_id: @line.id, quantity: 1, restock: false } ]
    )

    assert first.success?
    assert @order.reload.partially_refunded?

    second = Orders::ProcessRefund.call(
      order: @order,
      actor: @admin,
      line_params: [ { order_line_id: @line.id, quantity: 1, restock: false } ]
    )

    assert second.success?
    assert_equal "full", second.refund.refund_type
    assert @order.reload.refunded?
  end

  test "does not update last_restocked_at when restocking via refund" do
    product = @line.sellable
    original_time = 1.week.ago
    product.update_column(:last_restocked_at, original_time)

    line_params = [
      { order_line_id: @line.id, quantity: 1, restock: true }
    ]

    Orders::ProcessRefund.call(order: @order, actor: @admin, line_params: line_params)
    assert_in_delta original_time.to_f, product.reload.last_restocked_at.to_f, 0.001
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
