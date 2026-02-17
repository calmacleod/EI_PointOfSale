# frozen_string_literal: true

require "test_helper"

class OrdersControllerTest < ActionDispatch::IntegrationTest
  setup do
    @admin = users(:admin)
    sign_in_as(@admin)
  end

  test "GET /orders lists orders" do
    get orders_path
    assert_response :success
  end

  test "POST /orders creates a new draft order and redirects to register" do
    assert_difference "Order.count", 1 do
      post orders_path
    end
    assert_redirected_to register_path(order_id: Order.last.id)
  end

  test "GET /orders/:id shows a completed order" do
    get order_path(orders(:completed_order))
    assert_response :success
  end

  test "GET /orders/:id/edit redirects to register" do
    order = orders(:draft_order)
    get edit_order_path(order)
    assert_redirected_to register_path(order_id: order.id)
  end

  test "POST /orders/:id/hold puts order on hold" do
    order = orders(:draft_order)
    post hold_order_path(order)
    assert_redirected_to register_path(order_id: order.id)
    assert order.reload.held?
  end

  test "POST /orders/:id/resume resumes a held order" do
    order = orders(:held_order)
    post resume_order_path(order)
    assert_redirected_to register_path(order_id: order.id)
    assert order.reload.draft?
  end

  test "POST /orders/:id/complete fails without payment" do
    order = orders(:draft_order)
    # Add a line item first
    product = products(:dragon_shield_red)
    line = order.order_lines.build(quantity: 1)
    line.snapshot_from_sellable!(product)
    line.position = 1
    line.save!
    Orders::CalculateTotals.call(order)

    post complete_order_path(order)
    assert_redirected_to register_path(order_id: order.id)
    assert order.reload.draft?
  end

  test "DELETE /orders/:id/cancel cancels a draft order" do
    order = orders(:draft_order)
    delete cancel_order_path(order)
    assert_redirected_to register_path
    assert order.reload.cancelled?
    assert_not order.discarded?
  end

  test "DELETE /orders/:id/cancel cancels a held order" do
    order = orders(:held_order)
    delete cancel_order_path(order)
    assert_redirected_to register_path
    assert order.reload.cancelled?
    assert_not order.discarded?
  end

  test "GET /orders/held shows held orders" do
    get held_orders_path
    assert_response :success
    assert_select "table"
  end

  test "GET /orders/held filters by search" do
    get held_orders_path(q: orders(:held_order).number)
    assert_response :success
  end

  test "GET /orders/held filters by cashier" do
    get held_orders_path(created_by_id: users(:admin).id)
    assert_response :success
  end

  test "GET /orders/held filters by customer" do
    held_order = orders(:held_order)
    held_order.update!(customer: customers(:acme_corp))
    get held_orders_path(customer_id: customers(:acme_corp).id)
    assert_response :success
  end

  test "GET /orders/held filters by date range" do
    get held_orders_path(held_at_preset: "today")
    assert_response :success
  end

  test "GET /orders/held filters by total amount range" do
    get held_orders_path(total_min: 10, total_max: 100)
    assert_response :success
  end

  test "POST /orders/quick_lookup adds item via code" do
    order = orders(:draft_order)
    post quick_lookup_orders_path, params: { order_id: order.id, code: "DS-MAT-RED" },
         headers: { "Accept" => "text/vnd.turbo-stream.html" }
    assert_response :success
    assert order.order_lines.reload.any?
  end

  test "GET /orders/:id/receipt shows receipt for completed order" do
    get receipt_order_path(orders(:completed_order))
    assert_response :success
  end

  test "GET /orders/:id/refund_form shows refund form (admin)" do
    get refund_form_order_path(orders(:completed_order))
    assert_response :success
  end

  test "PATCH /orders/:id/assign_customer assigns a customer" do
    order = orders(:draft_order)
    customer = customers(:acme_corp)
    patch assign_customer_order_path(order), params: { customer_id: customer.id },
          headers: { "Accept" => "text/vnd.turbo-stream.html" }
    assert_response :success
    assert_equal customer, order.reload.customer
  end

  test "DELETE /orders/:id/remove_customer removes the customer" do
    order = orders(:completed_order)
    # Use a draft order with customer
    draft = orders(:draft_order)
    draft.update_column(:customer_id, customers(:acme_corp).id)

    delete remove_customer_order_path(draft),
           headers: { "Accept" => "text/vnd.turbo-stream.html" }
    assert_response :success
    assert_nil draft.reload.customer
  end
end
