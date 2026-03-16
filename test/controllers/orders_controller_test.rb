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

  test "POST /orders/quick_lookup applies discounts to the order" do
    order = orders(:draft_order)
    # dragon_shield_red is in discount_items fixtures, so discounts should apply
    post quick_lookup_orders_path, params: { order_id: order.id, code: "DS-MAT-RED" },
         headers: { "Accept" => "text/vnd.turbo-stream.html" }
    assert_response :success
    assert order.order_discounts.reload.any?, "Expected discounts to be applied via quick_lookup"
    assert_includes order.order_discounts.pluck(:discount_id), discounts(:percentage_all).id
  end

  test "POST /orders/quick_lookup renders discounts panel" do
    order = orders(:draft_order)
    post quick_lookup_orders_path, params: { order_id: order.id, code: "DS-MAT-RED" },
         headers: { "Accept" => "text/vnd.turbo-stream.html" }
    assert_response :success
    # Verify the turbo stream includes the discounts panel
    assert_select "turbo-stream[action=\"replace\"][target=\"order_discounts_panel\"]"
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

  # --- Complete SUCCESS path ---

  test "POST /orders/:id/complete succeeds with sufficient payment" do
    order = orders(:draft_order)
    product = products(:dragon_shield_red)
    line = order.order_lines.build(quantity: 1)
    line.snapshot_from_sellable!(product)
    line.position = 1
    line.save!
    Orders::CalculateTotals.call(order)
    order.reload
    order.order_payments.create!(
      payment_method: :cash, amount: order.total,
      amount_tendered: order.total, received_by: @admin
    )

    initial_stock = product.stock_level
    post complete_order_path(order)
    assert_redirected_to order_path(order)
    assert order.reload.completed?
    assert_equal initial_stock - 1, product.reload.stock_level
  end

  # --- PATCH update ---

  test "PATCH /orders/:id updates notes" do
    order = orders(:draft_order)
    patch order_path(order), params: { order: { notes: "Special instructions" } }
    assert_redirected_to register_path(order_id: order.id)
    assert_equal "Special instructions", order.reload.notes
  end

  test "PATCH /orders/:id updates tax_exempt status" do
    order = orders(:draft_order)
    patch order_path(order), params: { order: { tax_exempt: true } }
    assert_redirected_to register_path(order_id: order.id)
    assert order.reload.tax_exempt?
  end

  # --- process_refund ---

  test "POST /orders/:id/process_refund succeeds with valid line params" do
    order = orders(:completed_order)
    line = order.order_lines.first

    assert_difference "Refund.count", 1 do
      post process_refund_order_path(order), params: {
        refund_lines: [ { selected: "1", order_line_id: line.id, quantity: 1, restock: "0" } ],
        reason: "Customer request"
      }
    end
    assert order.reload.refunded? || order.reload.partially_refunded?
  end

  test "POST /orders/:id/process_refund fails with no lines selected" do
    order = orders(:completed_order)
    post process_refund_order_path(order), params: {
      refund_lines: [ { selected: "0", order_line_id: order.order_lines.first.id, quantity: 1, restock: "0" } ]
    }
    assert_response :unprocessable_entity
  end

  test "POST /orders/:id/process_refund is not accessible to common users" do
    sign_in_as(users(:one))
    order = orders(:completed_order)
    post process_refund_order_path(order), params: { reason: "test" }
    # CanCan redirects unauthorized access rather than returning 403
    assert_redirected_to root_path
  end

  # --- quick_lookup comprehensive Turbo assertions ---

  test "POST quick_lookup replaces all 6 turbo stream targets on success" do
    order = orders(:draft_order)
    post quick_lookup_orders_path, params: { order_id: order.id, code: "DS-MAT-RED" },
         headers: TURBO_HEADERS
    assert_response :success
    assert_turbo_stream_replaces("order_line_items", "order_discounts_panel", "order_totals",
                                 "order_payments_panel", "code_lookup_input_wrapper")
    # lookup_flash uses replace action on success
    assert_select "turbo-stream[target='lookup_flash']"
  end

  test "POST quick_lookup with unknown code renders warning in lookup_flash" do
    order = orders(:draft_order)
    post quick_lookup_orders_path, params: { order_id: order.id, code: "DOESNOTEXIST" },
         headers: TURBO_HEADERS
    assert_response :success
    # No items should be added
    assert_equal 0, order.order_lines.reload.count
    assert_turbo_stream_updates("lookup_flash")
  end

  # --- assign_customer / remove_customer Turbo assertions ---

  test "PATCH assign_customer replaces all 4 customer-related Turbo targets" do
    order = orders(:draft_order)
    patch assign_customer_order_path(order), params: { customer_id: customers(:acme_corp).id },
          headers: TURBO_HEADERS
    assert_response :success
    assert_turbo_stream_replaces("order_customer_panel", "order_discounts_panel",
                                 "order_line_items", "order_totals")
  end

  test "DELETE remove_customer replaces all 4 customer-related Turbo targets" do
    draft = orders(:draft_order)
    draft.update_column(:customer_id, customers(:acme_corp).id)
    delete remove_customer_order_path(draft), headers: TURBO_HEADERS
    assert_response :success
    assert_turbo_stream_replaces("order_customer_panel", "order_discounts_panel",
                                 "order_line_items", "order_totals")
  end
end
