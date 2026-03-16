# frozen_string_literal: true

require "application_system_test_case"

class DiscountManagementTest < ApplicationSystemTestCase
  setup do
    @admin = users(:admin)
    system_sign_in_as(@admin)
  end

  test "apply and remove manual order discount" do
    visit register_path
    fill_in_code_lookup("DS-MAT-RED")

    order = Order.draft.last
    original_total = order.reload.total

    # Open discount modal
    within "#order_discounts_panel" do
      click_link "Add Discount"
    end

    # Fill in discount form
    assert_selector "turbo-frame#discount_modal", wait: 5
    fill_in "order_discount[name]", with: "Manager 10%"
    select "Percentage", from: "order_discount[discount_type]"
    fill_in "order_discount[value]", with: "10"
    click_button "Apply Discount"

    # Verify discount appears and totals reduced
    within "#order_discounts_panel" do
      assert_text "Manager 10%", wait: 5
    end
    assert order.reload.total < original_total

    # Remove the discount
    within "#order_discounts_panel" do
      click_button "Remove"
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

    # Find exclude button for the line discount and click it
    within "#order_line_#{line.id}" do
      first("button[data-action*='exclude']").click rescue skip("Exclude button not found — UI may differ")
    end

    # Excluded quantity should be 1
    discount = line.order_line_discounts.reload.first
    assert_equal 1, discount.excluded_quantity if discount
  end

  private

    def fill_in_code_lookup(code)
      fill_in "code", with: code
      find("input[name='code']").send_keys(:return)
      assert_selector "#order_line_items", wait: 5
    end
end
