# frozen_string_literal: true

require "application_system_test_case"
require_relative "../test_helpers/register_helper"

class CheckoutFlowTest < ApplicationSystemTestCase
  include RegisterHelper
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

    # Complete the order via the Svelte confirmation prompt
    assert_selector "#complete_prompt_modal", wait: 5
    within "#complete_prompt_modal" do
      click_button "Complete order"
    end

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
      assert_text format_currency(Order.draft.last.reload.total), wait: 5
    end
  end

  test "hold and resume order" do
    visit register_path
    fill_in_code_lookup("DS-MAT-RED")

    # Hold the order
    click_button "Hold"
    assert_current_path register_path, ignore_query: true

    # Visit held orders
    visit held_orders_path
    assert_text "ORD-"

    # Resume via the register
    order = Order.held.last
    visit register_path(order_id: order.id)

    click_button "Resume order"
    # Wait for navigation to complete — after resume the action buttons change to Hold/Complete
    assert_selector "button", text: "Hold", wait: 5
    assert order.reload.draft?
  end

  test "assign customer and verify panel updates" do
    visit register_path
    fill_in_code_lookup("DS-MAT-RED")

    assign_customer("Acme Corp")
  end
end
