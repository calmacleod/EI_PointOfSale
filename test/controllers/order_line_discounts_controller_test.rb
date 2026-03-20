# frozen_string_literal: true

require "test_helper"

class OrderLineDiscountsControllerTest < ActionDispatch::IntegrationTest
  setup do
    @admin = users(:admin)
    sign_in_as(@admin)
    @order = orders(:draft_order)

    # Add a line item with quantity 3 so we can test exclude/restore
    @line = @order.order_lines.build(quantity: 3)
    @line.snapshot_from_sellable!(products(:dragon_shield_red))
    @line.position = 1
    @line.save!
    Orders::CalculateTotals.call(@order)
    @order.reload
  end

  def line_discount_params(line_id, applied_count)
    {
      order_line_discount: {
        name: "Manual 10%",
        discount_type: "percentage",
        value: 10,
        line_quantities: { line_id.to_s => applied_count.to_s }
      }
    }
  end

  # POST create
  test "POST creates line discount for specified line" do
    assert_difference "OrderLineDiscount.count", 1 do
      post order_order_line_discounts_path(@order),
           params: line_discount_params(@line.id, 3),
           headers: TURBO_HEADERS
    end
    assert_response :success
  end

  test "POST skips lines with zero applied_count" do
    assert_no_difference "OrderLineDiscount.count" do
      post order_order_line_discounts_path(@order),
           params: line_discount_params(@line.id, 0),
           headers: TURBO_HEADERS
    end
    assert_response :success
  end

  test "POST clamps applied_count to line quantity" do
    post order_order_line_discounts_path(@order),
         params: {
           order_line_discount: {
             name: "Clamped Discount",
             discount_type: "percentage",
             value: 10,
             line_quantities: { @line.id.to_s => "99" }
           }
         }, headers: TURBO_HEADERS

    created = OrderLineDiscount.last
    # excluded_quantity = line.quantity - min(applied, quantity) = 3 - 3 = 0
    assert_equal 0, created.excluded_quantity
    assert_equal @line.quantity, created.applied_quantity
  end

  test "POST skips GiftCertificate sellable lines" do
    gc = GiftCertificate.create!(
      code: "GC-TESTMANUAL", status: :pending, initial_amount: 50, remaining_balance: 50,
      issued_by: @admin
    )
    gc_line = @order.order_lines.build(quantity: 1, sellable: gc, code: gc.code,
                                       name: "Gift Certificate $50.00", unit_price: 50,
                                       tax_rate: 0, tax_amount: 0, line_total: 50, position: 2)
    gc_line.save!

    assert_no_difference "OrderLineDiscount.count" do
      post order_order_line_discounts_path(@order),
           params: {
             order_line_discount: {
               name: "GC Discount",
               discount_type: "percentage",
               value: 10,
               line_quantities: { gc_line.id.to_s => "1" }
             }
           }, headers: TURBO_HEADERS
    end
  end

  test "POST recalculates order totals" do
    original_total = @order.total
    post order_order_line_discounts_path(@order),
         params: line_discount_params(@line.id, 3),
         headers: TURBO_HEADERS
    assert @order.reload.total < original_total
  end

  test "POST records a discount_applied event" do
    assert_difference "OrderEvent.count", 1 do
      post order_order_line_discounts_path(@order),
           params: line_discount_params(@line.id, 3),
           headers: TURBO_HEADERS
    end
    assert_equal "discount_applied", @order.order_events.last.event_type
  end

  test "POST returns turbo stream replacing order panels" do
    post order_order_line_discounts_path(@order),
         params: line_discount_params(@line.id, 3),
         headers: TURBO_HEADERS
    assert_response :success
    assert_turbo_stream_replaces(*ORDER_PANELS)
  end

  # DELETE destroy
  test "DELETE removes a manual line discount" do
    discount = @line.order_line_discounts.create!(
      name: "Manual", discount_type: :percentage, value: 10,
      calculated_amount: 4.50, excluded_quantity: 0, auto_applied: false
    )

    assert_difference "OrderLineDiscount.count", -1 do
      delete order_line_discount_path(discount), headers: TURBO_HEADERS
    end
    assert_response :success
  end

  test "DELETE recalculates totals after removing discount" do
    discount = @line.order_line_discounts.create!(
      name: "Manual", discount_type: :percentage, value: 10,
      calculated_amount: 4.50, excluded_quantity: 0, auto_applied: false
    )
    Orders::CalculateTotals.call(@order)
    @order.reload
    discounted_total = @order.total

    delete order_line_discount_path(discount), headers: TURBO_HEADERS

    assert @order.reload.total > discounted_total
  end

  test "DELETE records a discount_removed event" do
    discount = @line.order_line_discounts.create!(
      name: "Manual", discount_type: :percentage, value: 10,
      calculated_amount: 4.50, excluded_quantity: 0, auto_applied: false
    )

    assert_difference "OrderEvent.count", 1 do
      delete order_line_discount_path(discount), headers: TURBO_HEADERS
    end
    assert_equal "discount_removed", @order.order_events.last.event_type
  end

  test "DELETE returns turbo stream replacing order panels" do
    discount = @line.order_line_discounts.create!(
      name: "Manual", discount_type: :percentage, value: 10,
      calculated_amount: 4.50, excluded_quantity: 0, auto_applied: false
    )
    delete order_line_discount_path(discount), headers: TURBO_HEADERS
    assert_response :success
    assert_turbo_stream_replaces(*ORDER_PANELS)
  end

  # PATCH update
  test "PATCH update sets applied quantity directly" do
    discount = @line.order_line_discounts.create!(
      name: "Auto", discount_type: :percentage, value: 10,
      calculated_amount: 4.50, excluded_quantity: 0, auto_applied: true
    )

    patch order_line_discount_path(discount),
          params: { order_line_discount: { applied_quantity: 1 } },
          headers: TURBO_HEADERS
    assert_response :success
    assert_equal 1, discount.reload.applied_quantity
    assert_equal 2, discount.excluded_quantity
  end

  test "PATCH update clamps to valid range" do
    discount = @line.order_line_discounts.create!(
      name: "Auto", discount_type: :percentage, value: 10,
      calculated_amount: 4.50, excluded_quantity: 0, auto_applied: true
    )

    patch order_line_discount_path(discount),
          params: { order_line_discount: { applied_quantity: 99 } },
          headers: TURBO_HEADERS
    assert_response :success
    assert_equal @line.quantity, discount.reload.applied_quantity
  end

  test "PATCH update returns turbo stream replacing line and panels" do
    discount = @line.order_line_discounts.create!(
      name: "Auto", discount_type: :percentage, value: 10,
      calculated_amount: 4.50, excluded_quantity: 0, auto_applied: true
    )

    patch order_line_discount_path(discount),
          params: { order_line_discount: { applied_quantity: 2 } },
          headers: TURBO_HEADERS
    assert_response :success
    assert_turbo_stream_replaces("order_line_#{@line.id}", "order_discounts_panel", "order_totals")
  end
end
