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
    click_button "Complete"

    # Verify redirect to this order's show page
    assert_current_path order_path(order), wait: 5
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
    click_button "Hold"
    assert_current_path register_path

    # Visit held orders
    visit held_orders_path
    assert_text "ORD-"

    # Resume via the register
    order = Order.held.last
    visit register_path(order_id: order.id)

    click_button "Resume Order"
    # Wait for navigation to complete — after resume the action buttons change to Hold/Complete
    assert_selector "button", text: "Hold", wait: 5
    assert order.reload.draft?
  end

  test "assign customer and verify panel updates" do
    visit register_path
    fill_in_code_lookup("DS-MAT-RED")

    # Open customer search modal via the panel button
    within "#order_customer_panel" do
      click_button "Search & assign customer"
    end

    # Fill in search in the now-visible modal
    assert_selector "#customer_search_modal:not(.hidden)", wait: 5
    within "#customer_search_modal" do
      fill_in placeholder: /search by name/i, with: "Acme"
    end

    # Click the customer in results
    assert_text "Acme Corp", wait: 5
    click_on "Acme Corp"

    within "#order_customer_panel" do
      assert_text "Acme Corp", wait: 5
    end
  end

  private

    def fill_in_code_lookup(code)
      fill_in "code", with: code
      click_button "Add"
      assert_field "code", with: "", wait: 5
    end

    def fill_in_payment(method:, amount:, tendered: nil)
      within "#order_payments_panel" do
        find("button[data-method='#{method}']").click
        find("[name='order_payment[amount]']").set(amount.to_s)
        find("[name='order_payment[amount_tendered]']").set(tendered.to_s) if tendered
        click_button "Record Payment"
      end
      assert_selector "#order_payments_panel", wait: 5
    end
end
