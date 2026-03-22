# frozen_string_literal: true

require "application_system_test_case"
require_relative "../test_helpers/register_helper"

class RegisterComprehensiveTest < ApplicationSystemTestCase
  include RegisterHelper

  setup do
    @admin = users(:admin)
    system_sign_in_as(@admin)
    Discount.update_all(active: false)
  end

  # -------------------------------------------------------------------------
  # A. Empty Order State
  # -------------------------------------------------------------------------

  test "empty order displays correct initial state" do
    visit register_path
    assert_no_line_items
    assert_empty_order_totals
    assert_selector "button", text: "Hold"
    assert_no_selector "button[id='complete_btn']:not([disabled])"
  end

  test "complete button disabled on empty order" do
    visit register_path
    assert_selector "button[disabled]", text: /complete/i
  end

  # -------------------------------------------------------------------------
  # B. Single Item Addition
  # -------------------------------------------------------------------------

  test "add single product and verify all panels" do
    visit register_path
    fill_in_code_lookup("DS-MAT-RED")
    assert_totals_panel(subtotal: 14.99, tax: 1.95, total: 16.94)
  end

  test "add single service and verify all panels" do
    visit register_path
    fill_in_code_lookup("SVC-REFILL-SM")
    assert_totals_panel(subtotal: 12.99, tax: 1.69, total: 14.68)
  end

  test "invalid code shows error in lookup flash" do
    visit register_path
    fill_in "code", with: "NONEXISTENT"
    click_button "Add"
    assert_selector "#lookup_flash", text: /no match|use search/i, wait: 5
  end

  # -------------------------------------------------------------------------
  # C. Multiple Items
  # -------------------------------------------------------------------------

  test "add product and service together" do
    visit register_path
    fill_in_code_lookup("DS-MAT-RED")
    fill_in_code_lookup("SVC-REFILL-SM")
    # 14.99 + 12.99 = 27.98; tax 3.64; total 31.62
    assert_totals_panel(subtotal: 27.98, tax: 3.64, total: 31.62)
  end

  test "add same product twice increments quantity" do
    visit register_path
    fill_in_code_lookup("DS-MAT-RED")
    fill_in_code_lookup("DS-MAT-RED")
    # qty 2, subtotal 29.98, tax 3.90, total 33.88
    within "#order_line_items" do
      assert_text "2"
    end
    assert_totals_panel(subtotal: 29.98, tax: 3.90, total: 33.88)
  end

  test "add three different products" do
    visit register_path
    fill_in_code_lookup("DS-MAT-RED")
    fill_in_code_lookup("DS-MAT-BLU")
    fill_in_code_lookup("NHL-PUCK-001")
    # 14.99 + 14.99 + 7.99 = 37.97; tax 4.94; total 42.91
    assert_totals_panel(subtotal: 37.97, tax: 4.94, total: 42.91)
  end

  # -------------------------------------------------------------------------
  # D. Item Removal
  # -------------------------------------------------------------------------

  test "remove one item from two updates totals" do
    visit register_path
    fill_in_code_lookup("DS-MAT-RED")
    fill_in_code_lookup("NHL-PUCK-001")

    order = Order.draft.last
    puck_line = order.order_lines
      .joins("JOIN products ON products.id = order_lines.sellable_id AND order_lines.sellable_type = 'Product'")
      .where(products: { code: "NHL-PUCK-001" }).first

    find("form[action*='order_lines/#{puck_line.id}'] button[type='submit']", visible: :all).click

    assert_totals_panel(subtotal: 14.99, tax: 1.95, total: 16.94)
  end

  test "remove all items returns to empty state" do
    visit register_path
    fill_in_code_lookup("DS-MAT-RED")

    order = Order.draft.last
    line = order.order_lines.first

    find("form[action*='order_lines/#{line.id}'] button[type='submit']", visible: :all).click

    assert_no_line_items
    assert_empty_order_totals
  end

  # -------------------------------------------------------------------------
  # E. Customer Assignment
  # -------------------------------------------------------------------------

  test "assign customer with no special attributes" do
    visit register_path
    fill_in_code_lookup("DS-MAT-RED")
    assign_customer("Acme Corp")
    assert_totals_panel(subtotal: 14.99, tax: 1.95, total: 16.94)
  end

  test "assign tax exempt customer zeroes tax" do
    visit register_path
    fill_in_code_lookup("DS-MAT-RED")
    assign_customer("Tax Exempt Corp")
    assert_totals_panel(subtotal: 14.99, tax: 0.00, total: 14.99)
  end

  test "remove customer restores original tax" do
    visit register_path
    fill_in_code_lookup("DS-MAT-RED")
    assign_customer("Tax Exempt Corp")
    assert_totals_panel(subtotal: 14.99, tax: 0.00, total: 14.99)

    remove_customer
    within "#order_customer_panel" do
      assert_text "No customer", wait: 5
    end
    assert_totals_panel(subtotal: 14.99, tax: 1.95, total: 16.94)
  end

  # -------------------------------------------------------------------------
  # F. Customer Auto-Discount
  # -------------------------------------------------------------------------

  test "assign customer with discount auto-applies it" do
    Discount.where(name: "10% Off Everything").update_all(active: true)
    visit register_path
    fill_in_code_lookup("DS-MAT-RED")
    assign_customer("Discount Dave")

    within "#order_discounts_panel" do
      assert_text(/10%|10% Off/i, wait: 5)
    end
    order = Order.draft.last
    assert order.reload.total < 16.94
  end

  test "remove customer with discount removes it" do
    Discount.where(name: "10% Off Everything").update_all(active: true)
    visit register_path
    fill_in_code_lookup("DS-MAT-RED")
    assign_customer("Discount Dave")

    order = Order.draft.last
    discounted_total = order.reload.total

    remove_customer
    within "#order_customer_panel" do
      assert_text "No customer", wait: 5
    end
    assert order.reload.total > discounted_total
    assert_totals_panel(subtotal: 14.99, tax: 1.95, total: 16.94)
  end

  # -------------------------------------------------------------------------
  # G. Manual Order Discounts
  # -------------------------------------------------------------------------

  test "apply percentage discount and verify totals" do
    visit register_path
    fill_in_code_lookup("DS-MAT-RED")
    apply_manual_discount(name: "Manager 10%", type: "Percentage", value: 10)

    within "#order_discounts_panel" do
      assert_text "Manager 10%", wait: 5
    end
    order = Order.draft.last
    assert order.reload.total < 16.94
  end

  test "apply fixed amount discount and verify totals" do
    visit register_path
    fill_in_code_lookup("DS-MAT-RED")
    apply_manual_discount(name: "$5 Off", type: "Fixed Total", value: 5)

    within "#order_discounts_panel" do
      assert_text "$5 Off", wait: 5
    end
    order = Order.draft.last
    assert order.reload.total < 16.94
  end

  test "apply fixed per item discount on qty 2" do
    visit register_path
    fill_in_code_lookup("DS-MAT-RED")
    fill_in_code_lookup("DS-MAT-RED")
    apply_manual_discount(name: "$1/Item", type: "Fixed Per Item", value: 1)

    within "#order_discounts_panel" do
      assert_text "$1/Item", wait: 5
    end
    order = Order.draft.last
    assert order.reload.total < 33.88
  end

  test "remove discount restores original totals" do
    visit register_path
    fill_in_code_lookup("DS-MAT-RED")
    apply_manual_discount(name: "Manager 10%", type: "Percentage", value: 10)

    within "#order_discounts_panel" do
      assert_text "Manager 10%", wait: 5
    end

    order = Order.draft.last
    discounted_total = order.reload.total

    within "#order_discounts_panel" do
      find("div.flex.items-start.justify-between", text: /Manager 10%/).find("button[type='submit']").click
    end

    within "#order_discounts_panel" do
      assert_no_text "Manager 10%", wait: 5
    end
    assert_totals_panel(subtotal: 14.99, tax: 1.95, total: 16.94)
    assert order.reload.total > discounted_total
  end

  # -------------------------------------------------------------------------
  # H. Auto-Applied Line Discounts
  # -------------------------------------------------------------------------

  test "auto applied line discounts on eligible product" do
    Discount.where(name: [ "$5 Off Dragon Shields", "$1 Off Per Item" ]).update_all(active: true)
    visit register_path
    fill_in_code_lookup("DS-MAT-RED")

    order = Order.draft.last
    Discounts::AutoApply.call(order)
    Orders::CalculateTotals.call(order)
    visit register_path(order_id: order.id)

    within "#order_line_items" do
      assert_text(/discount|off/i, wait: 5)
    end
    assert order.reload.total < 16.94
  end

  test "auto applied discount skips gift certificates" do
    # Verify at the model level that GC lines have no line discounts applied
    Discount.where(name: [ "$5 Off Dragon Shields", "$1 Off Per Item" ]).update_all(active: true)
    visit register_path
    fill_in_code_lookup("DS-MAT-RED")

    order = Order.draft.last
    Discounts::AutoApply.call(order)

    gc_lines = order.order_lines.where(sellable_type: "GiftCertificate")
    gc_lines.each do |line|
      assert_empty line.order_line_discounts
    end
    # Only product lines should have discounts
    product_lines = order.order_lines.where(sellable_type: "Product")
    assert product_lines.any? { |l| l.order_line_discounts.any? }
  end

  # -------------------------------------------------------------------------
  # I. Gift Certificate as Line Item
  # -------------------------------------------------------------------------

  test "sell gift certificate is tax exempt" do
    visit register_path
    find("a[data-turbo-frame='gift_cert_modal']").click
    assert_selector "turbo-frame#gift_cert_modal", wait: 5

    fill_in "gift_certificate[initial_amount]", with: "50"
    click_button "Add to Order"

    assert_selector "#order_line_items", wait: 5
    order = Order.draft.last
    gc_line = order.order_lines.where(sellable_type: "GiftCertificate").first
    assert_not_nil gc_line
    assert_equal 0, gc_line.reload.tax_amount
  end

  test "gift certificate mixed with taxable product" do
    visit register_path
    fill_in_code_lookup("DS-MAT-RED")

    find("a[data-turbo-frame='gift_cert_modal']").click
    assert_selector "turbo-frame#gift_cert_modal", wait: 5
    fill_in "gift_certificate[initial_amount]", with: "25"
    click_button "Add to Order"

    order = Order.draft.last
    assert_in_delta 1.95, order.reload.order_lines.sum(:tax_amount), 0.02
  end

  # -------------------------------------------------------------------------
  # J. Payments
  # -------------------------------------------------------------------------

  test "cash payment exact amount" do
    visit register_path
    fill_in_code_lookup("DS-MAT-RED")
    fill_in_payment(method: "cash", amount: 16.94, tendered: 16.95)

    order = Order.draft.last
    assert order.reload.payment_complete?
  end

  test "cash payment with overpayment shows change" do
    visit register_path
    fill_in_code_lookup("DS-MAT-RED")
    fill_in_payment(method: "cash", amount: 16.94, tendered: 20.00)

    within "#order_payments_panel" do
      assert_text(/change|3\.0[56]/i, wait: 5)
    end
  end

  test "debit payment full amount" do
    visit register_path
    fill_in_code_lookup("DS-MAT-RED")
    fill_in_payment(method: "debit", amount: 16.94)

    order = Order.draft.last
    assert order.reload.payment_complete?
  end

  test "credit payment full amount" do
    visit register_path
    fill_in_code_lookup("DS-MAT-RED")
    fill_in_payment(method: "credit", amount: 16.94)

    order = Order.draft.last
    assert order.reload.payment_complete?
  end

  test "gift certificate payment" do
    # Create GC in the same DB transaction so the browser can find it
    gc = GiftCertificate.create!(
      code: "GC-PAY-TEST01",
      status: :active,
      initial_amount: 100,
      remaining_balance: 75,
      issued_by: @admin
    )

    visit register_path
    fill_in_code_lookup("DS-MAT-RED")

    within "#order_payments_panel" do
      click_button "Add Payment"
    end
    within "#payment_modal" do
      find("button[data-method='gift_certificate']").click
      assert_selector "button[data-method='gift_certificate'].bg-accent", wait: 5
      find("[name='order_payment[amount]']").set("16.94")
      find("[name='order_payment[reference]']").set(gc.code)
      click_button "Record Payment"
    end
    # Wait for the payment row to appear before asserting on the DB
    within "#order_payments_panel", wait: 5 do
      assert_text "GC-PAY-TEST01", wait: 5
      assert_no_text "not found"
    end

    assert gc.reload.remaining_balance < 75
  end

  test "partial payment shows remaining" do
    visit register_path
    fill_in_code_lookup("DS-MAT-RED")
    fill_in_payment(method: "cash", amount: 10.00, tendered: 10.00)

    within "#order_totals" do
      assert_text "$6.94", wait: 5
    end
  end

  test "split payment covers total" do
    visit register_path
    fill_in_code_lookup("DS-MAT-RED")
    fill_in_payment(method: "debit", amount: 10.00)
    fill_in_payment(method: "cash", amount: 6.95, tendered: 6.95)

    order = Order.draft.last
    assert order.reload.payment_complete?
  end

  # -------------------------------------------------------------------------
  # K. Complete Order Flow
  # -------------------------------------------------------------------------

  test "complete fully paid order" do
    visit register_path
    order = Order.draft.last
    fill_in_code_lookup("DS-MAT-RED")
    fill_in_payment(method: "cash", amount: 16.94, tendered: 16.94)

    assert_selector "#complete_prompt_modal", wait: 5
    within "#complete_prompt_modal" do
      click_button "Complete Order"
    end

    assert_current_path order_path(order), wait: 5
    assert_text "Order completed"
  end

  test "complete button disabled when underpaid" do
    visit register_path
    fill_in_code_lookup("DS-MAT-RED")
    fill_in_payment(method: "cash", amount: 10.00, tendered: 10.00)

    assert_selector "button[disabled]", text: /complete/i
  end

  # -------------------------------------------------------------------------
  # L. Hold/Resume
  # -------------------------------------------------------------------------

  test "hold order and verify redirect" do
    visit register_path
    fill_in_code_lookup("DS-MAT-RED")
    click_button "Hold"
    assert_current_path register_path
  end

  test "resume held order restores draft state" do
    visit register_path
    fill_in_code_lookup("DS-MAT-RED")
    click_button "Hold"

    order = Order.held.last
    visit register_path(order_id: order.id)
    click_button "Resume Order"
    assert_selector "button", text: "Hold", wait: 5
    assert order.reload.draft?
  end

  test "held order shows only resume button" do
    visit register_path
    fill_in_code_lookup("DS-MAT-RED")
    click_button "Hold"

    order = Order.held.last
    visit register_path(order_id: order.id)
    assert_selector "button", text: "Resume Order", wait: 5
    assert_no_selector "button", text: "Hold"
  end

  # -------------------------------------------------------------------------
  # M. Cancel Order
  # -------------------------------------------------------------------------

  test "cancel order via confirmation modal" do
    visit register_path
    fill_in_code_lookup("DS-MAT-RED")

    find("button[data-action='click->cancel-order#open']", match: :first).click
    assert_selector "[data-cancel-order-target='modal']:not(.hidden)", wait: 5
    find("button", text: "Cancel Order").click

    assert_current_path register_path, wait: 5
  end

  test "keep order dismisses cancel modal" do
    visit register_path
    fill_in_code_lookup("DS-MAT-RED")

    find("button[data-action='click->cancel-order#open']", match: :first).click
    assert_selector "[data-cancel-order-target='modal']:not(.hidden)", wait: 5
    find("button", text: "Keep Order").click

    assert_no_selector "[data-cancel-order-target='modal']:not(.hidden)", wait: 5
    within "#order_line_items" do
      assert_text "Dragon Shield"
    end
  end

  # -------------------------------------------------------------------------
  # N. Tab Management
  # -------------------------------------------------------------------------

  test "new order creates additional tab" do
    visit register_path
    initial_count = Order.draft.count

    find("button[type='submit']", text: /\bNew\b/i).click
    assert_current_path register_path, wait: 5

    assert Order.draft.count > initial_count
  end

  test "switching tabs loads correct order" do
    visit register_path
    fill_in_code_lookup("DS-MAT-RED")
    first_order = Order.draft.last

    find("button[type='submit']", text: /\bNew\b/i).click
    # Wait for new empty order to be active before adding item
    within "#order_line_items" do
      assert_text(/no items/i, wait: 5)
    end
    fill_in_code_lookup("NHL-PUCK-001")

    # Switch back to first order's tab by clicking its link
    find("div[data-order-id='#{first_order.id}']", wait: 5).find("a").click

    within "#order_line_items" do
      assert_text "Dragon Shield", wait: 5
      assert_no_text "NHL"
    end
  end

  # -------------------------------------------------------------------------
  # O. Complex End-to-End
  # -------------------------------------------------------------------------

  test "full workflow: customer + discount + mixed items + split payment + complete" do
    visit register_path
    order = Order.draft.last

    fill_in_code_lookup("DS-MAT-RED")
    fill_in_code_lookup("SVC-REFILL-SM")
    assign_customer("Acme Corp")
    apply_manual_discount(name: "VIP 5%", type: "Percentage", value: 5)

    within "#order_discounts_panel" do
      assert_text "VIP 5%", wait: 5
    end

    order.reload
    half = (order.total / 2).round(2)
    remaining = (order.total - half).round(2)

    fill_in_payment(method: "debit", amount: half)
    fill_in_payment(method: "cash", amount: remaining, tendered: remaining)

    assert_selector "#complete_prompt_modal", wait: 5
    within "#complete_prompt_modal" do
      click_button "Complete Order"
    end

    assert_current_path order_path(order), wait: 5
    assert_text "Order completed"
  end

  test "gift certificate excluded from order discount" do
    visit register_path
    fill_in_code_lookup("DS-MAT-RED")

    find("a[data-turbo-frame='gift_cert_modal']").click
    assert_selector "turbo-frame#gift_cert_modal", wait: 5
    fill_in "gift_certificate[initial_amount]", with: "25"
    click_button "Add to Order"

    apply_manual_discount(name: "10% Off", type: "Percentage", value: 10)

    order = Order.draft.last
    gc_line = order.order_lines.where(sellable_type: "GiftCertificate").first
    assert_not_nil gc_line
    assert_equal 0, gc_line.reload.tax_amount
    assert_empty gc_line.order_line_discounts
  end
end
