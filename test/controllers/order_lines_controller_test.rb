# frozen_string_literal: true

require "test_helper"

class OrderLinesControllerTest < ActionDispatch::IntegrationTest
  setup do
    @admin = users(:admin)
    sign_in_as(@admin)
    @order = orders(:draft_order)
    @product = products(:dragon_shield_red)
  end

  test "POST /orders/:id/order_lines creates a line item" do
    assert_difference "OrderLine.count", 1 do
      post order_order_lines_path(@order), params: {
        sellable_type: "Product", sellable_id: @product.id, quantity: 2
      }
    end
    assert_redirected_to register_path(order_id: @order.id)
  end

  test "PATCH /order_lines/:id updates quantity" do
    line = @order.order_lines.create!(
      sellable: @product, code: @product.code, name: @product.name,
      quantity: 1, unit_price: @product.selling_price, tax_rate: 0.13,
      tax_amount: 1.95, line_total: 16.94, position: 1
    )

    patch order_line_path(line), params: { order_line: { quantity: 5 } }
    assert_redirected_to register_path(order_id: @order.id)
    assert_equal 5, line.reload.quantity
  end

  test "DELETE /order_lines/:id removes a line item" do
    line = @order.order_lines.create!(
      sellable: @product, code: @product.code, name: @product.name,
      quantity: 1, unit_price: @product.selling_price, tax_rate: 0.13,
      tax_amount: 1.95, line_total: 16.94, position: 1
    )

    assert_difference "OrderLine.count", -1 do
      delete order_line_path(line)
    end
    assert_redirected_to register_path(order_id: @order.id)
  end

  test "POST creates a Service line item" do
    service = services(:printer_refill)
    assert_difference "OrderLine.count", 1 do
      post order_order_lines_path(@order), params: {
        sellable_type: "Service", sellable_id: service.id, quantity: 1
      }
    end
    assert_redirected_to register_path(order_id: @order.id)
    assert_equal service.name, OrderLine.last.name
  end

  test "POST creates a separate line when same product is added again via controller" do
    # The controller calls OrderLines::Add without increment_if_exists,
    # so each manual add creates a new line. Incrementing is handled by quick_lookup.
    post order_order_lines_path(@order), params: {
      sellable_type: "Product", sellable_id: @product.id, quantity: 1
    }

    assert_difference "OrderLine.count", 1 do
      post order_order_lines_path(@order), params: {
        sellable_type: "Product", sellable_id: @product.id, quantity: 1
      }
    end
    assert_equal 2, @order.order_lines.reload.count
  end

  test "DELETE last line item reduces order to 0 lines" do
    line = @order.order_lines.create!(
      sellable: @product, code: @product.code, name: @product.name,
      quantity: 1, unit_price: @product.selling_price, tax_rate: 0.13,
      tax_amount: 1.95, line_total: 16.94, position: 1
    )

    delete order_line_path(line)
    assert_equal 0, @order.order_lines.reload.count
    assert_equal 0, @order.reload.total
  end
end
