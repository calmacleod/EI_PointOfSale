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
      }, headers: { "Accept" => "text/vnd.turbo-stream.html" }
    end
    assert_response :success
  end

  test "PATCH /order_lines/:id updates quantity" do
    line = @order.order_lines.create!(
      sellable: @product, code: @product.code, name: @product.name,
      quantity: 1, unit_price: @product.selling_price, tax_rate: 0.13,
      tax_amount: 1.95, line_total: 16.94, position: 1
    )

    patch order_line_path(line), params: { order_line: { quantity: 5 } },
          headers: { "Accept" => "text/vnd.turbo-stream.html" }
    assert_response :success
    assert_equal 5, line.reload.quantity
  end

  test "DELETE /order_lines/:id removes a line item" do
    line = @order.order_lines.create!(
      sellable: @product, code: @product.code, name: @product.name,
      quantity: 1, unit_price: @product.selling_price, tax_rate: 0.13,
      tax_amount: 1.95, line_total: 16.94, position: 1
    )

    assert_difference "OrderLine.count", -1 do
      delete order_line_path(line),
             headers: { "Accept" => "text/vnd.turbo-stream.html" }
    end
    assert_response :success
  end
end
