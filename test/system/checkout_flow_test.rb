# frozen_string_literal: true

require "application_system_test_case"

class CheckoutFlowTest < ApplicationSystemTestCase
  setup do
    @admin = users(:admin)
    system_sign_in_as(@admin)
  end

  test "basic checkout: add product, pay, complete" do
    visit register_path
    order = Order.draft.last

    # Add product via quick lookup
    fill_in_code_lookup("DS-MAT-RED")

    # Verify line item appears
    within "#order_line_items" do
      assert_text "Dragon Shield"
    end

    # Add cash payment for full amount
    order.reload
    fill_in_payment(method: "cash", amount: order.total, tendered: order.total + 5)

    # Complete the order
    click_button "Complete Order"

    # Verify redirect to completed order
    assert_current_path order_path(Order.completed.last)
    assert_text "Order completed"
  end

  test "add two products and verify totals update" do
    visit register_path

    fill_in_code_lookup("DS-MAT-RED")
    within "#order_line_items" do
      assert_text "Dragon Shield"
    end

    fill_in_code_lookup("NHL-PUCK-001")
    within "#order_line_items" do
      assert_text "NHL Team Puck"
    end

    # Verify totals panel shows non-zero total
    within "#order_totals" do
      assert_no_text "$0.00"
    end
  end

  test "hold and resume order" do
    visit register_path
    fill_in_code_lookup("DS-MAT-RED")

    # Hold the order
    click_button "Hold Order"
    assert_current_path register_path

    # Visit held orders
    visit held_orders_path
    assert_text "ORD-"

    # Resume via the register
    order = Order.held.last
    visit register_path(order_id: order.id)

    click_button "Resume"
    assert order.reload.draft?
  end

  test "assign customer and verify panel updates" do
    visit register_path
    fill_in_code_lookup("DS-MAT-RED")

    # Search for customer via customer panel
    within "#order_customer_panel" do
      fill_in placeholder: /search/i, with: "Acme"
      find("button[type='submit']").click
    end

    # Click the customer in results
    assert_text "Acme Corp"
    click_on "Acme Corp"

    within "#order_customer_panel" do
      assert_text "Acme Corp"
    end
  end

  private

    def fill_in_code_lookup(code)
      fill_in "code", with: code
      find("input[name='code']").send_keys(:return)
      # Wait for Turbo stream to update line items
      assert_selector "#order_line_items", wait: 5
    end

    def fill_in_payment(method:, amount:, tendered: nil)
      within "#order_payments_panel" do
        select method.humanize, from: "order_payment[payment_method]"
        fill_in "order_payment[amount]", with: amount.to_s
        fill_in "order_payment[amount_tendered]", with: tendered.to_s if tendered
        find("button[type='submit']").click
      end
      assert_selector "#order_payments_panel", wait: 5
    end
end
