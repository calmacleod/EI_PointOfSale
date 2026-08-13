# frozen_string_literal: true

require "application_system_test_case"
require_relative "../test_helpers/register_helper"

class DiscountManagementTest < ApplicationSystemTestCase
  include RegisterHelper
  setup do
    @admin = users(:admin)
    system_sign_in_as(@admin)
  end

  test "apply and remove manual order discount" do
    visit register_path
    fill_in_code_lookup("DS-MAT-RED")

    order = Order.draft.last
    original_total = order.reload.total

    apply_manual_discount(name: "Manager 10%", type: "Percentage", value: 10)

    # Verify discount appears and totals reduced
    within "#order_discounts_panel" do
      assert_text "Manager 10%", wait: 5
    end
    assert order.reload.total < original_total

    within "#order_discounts_panel" do
      find("button[aria-label='Remove Manager 10%']").click
    end

    within "#order_discounts_panel" do
      assert_no_text "Manager 10%", wait: 5
    end
    assert_equal original_total, order.reload.total
  end

  test "exclude discount from one unit of a multi-quantity line" do
    # Add product with qty 2 via quick lookup twice
    visit register_path
    fill_in_code_lookup("DS-MAT-RED")
    fill_in_code_lookup("DS-MAT-RED")

    # The line should now have quantity 2
    order = Order.draft.last
    line = order.order_lines.reload.first
    assert_equal 2, line.quantity

    # Ensure auto-discount was applied
    Discounts::AutoApply.call(order)
    Orders::CalculateTotals.call(order)

    visit register_path(order_id: order.id)

    # Reduce the auto-applied quantity from 2 to 1, excluding one unit.
    within "#order_line_#{line.id}" do
      input = all("input[aria-label^='Discount quantity']").first
      input.set("1")
      input.send_keys(:tab)
    end
    assert_selector "#order_discounts_panel", text: "1 of 2 units", wait: 5

    # Excluded quantity should be 1
    excluded_quantities = line.order_line_discounts.reload.map(&:excluded_quantity)
    assert_includes excluded_quantities, 1
  end
end
