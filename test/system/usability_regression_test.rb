# frozen_string_literal: true

require "application_system_test_case"
require_relative "../test_helpers/register_helper"

class UsabilityRegressionTest < ApplicationSystemTestCase
  include RegisterHelper
  setup do
    @admin = users(:admin)
    system_sign_in_as(@admin)
  end

  test "filtered products and customers open the record shown" do
    product = products(:nhl_puck)
    visit products_path
    fill_in "resource-search", with: product.code
    click_button "Apply"
    within "#products_table tbody" do
      assert_selector "tr", count: 1
      click_link product.code
    end
    assert_current_path product_path(product)
    click_link "Stock history"
    assert_current_path product_restocks_path(product)
    click_button "Back to product"
    assert_current_path product_path(product)

    visit products_path
    fill_in "resource-search", with: product.code
    click_button "Apply"
    within "#products_table tbody" do
      assert_selector "tr", count: 1
      click_link "Edit"
    end
    assert_current_path edit_product_path(product)
    assert_field "Name", with: product.name

    customer = customers(:jane_doe)
    visit customers_path
    fill_in "resource-search", with: customer.name
    click_button "Apply"
    within "#customers_table tbody" do
      assert_selector "tr", count: 1
      first("a").click
    end
    assert_current_path customer_path(customer)
    assert_text customer.name
  end

  test "tax exemption toggles existing and new lines and reaches the receipt" do
    order = orders(:draft_order)
    OrderLines::Add.call(order: order, sellable: products(:nhl_puck), actor: @admin)
    visit register_path(order_id: order.id)
    check "Tax exempt"
    assert_selector "#order_totals .r-line", text: /\ATax\s+\$0\.00\z/
    assert_equal 0, order.reload.tax_total

    fill_in_code_lookup("DS-MAT-RED")
    assert_selector "#order_totals .r-line", text: /\ATax\s+\$0\.00\z/
    assert_equal 0, order.reload.tax_total

    uncheck "Tax exempt"
    assert_no_selector "#order_totals .r-line", text: /\ATax\s+\$0\.00\z/
    assert_operator order.reload.tax_total, :>, 0
    assert order.order_lines.all? { |line| line.tax_amount.positive? }

    check "Tax exempt"
    assert_selector "#order_totals .r-line", text: /\ATax\s+\$0\.00\z/
    exempt_total = order.reload.subtotal - order.discount_total
    assert_equal exempt_total, order.total
    fill_in_payment(method: "debit", amount: exempt_total)
    within "#complete_prompt_modal" do
      click_button "Complete order"
    end
    assert_current_path order_path(order)
    click_link "Receipt"
    assert_current_path receipt_order_path(order)
    assert_text format_currency(exempt_total)
    assert_equal 0, order.reload.tax_total
  end

  test "cash drawer closes reconciles and reopens without reloading" do
    drawer = cash_drawer_sessions(:open_session)
    visit cash_drawer_path
    click_link "Close register"
    find('input[aria-label="$20 count"]').set(5)
    click_button "Save drawer count"

    assert_current_path reconcile_cash_drawer_path
    assert_selector "#reconcile-form"
    assert_no_selector "#drawer-count-form"
    fill_in "Debit terminal total", with: "0"
    fill_in "Credit terminal total", with: "0"
    click_button "Save reconciliation"
    assert_current_path session_detail_cash_drawer_path(drawer)
    assert drawer.reload.closed?
    assert drawer.terminal_reconciliation.present?

    find('a[aria-label="Cash drawer"]').click
    click_link "Open register"
    assert_selector "#drawer-count-form"
    assert_equal "0", find('input[aria-label="$20 count"]').value
    find('input[aria-label="$20 count"]').set(10)
    click_button "Save drawer count"
    assert_current_path cash_drawer_path
    assert_text "$200.00"
    assert_equal 20_000, CashDrawerSession.current.opening_total_cents
  end

  test "returning one line does not block a later return and restock" do
    products = [ products(:dragon_shield_red), products(:nhl_puck) ]
    initial_stock = products.map(&:stock_level)
    order = Order.create!(created_by: @admin)
    products.each { |product| OrderLines::Add.call(order: order, sellable: product, actor: @admin) }
    order.order_payments.create!(payment_method: :debit, amount: order.reload.total, received_by: @admin)
    completion = Orders::Complete.call(order: order, actor: @admin)
    assert completion.success?, completion.errors.join(", ")

    visit order_path(order)
    products.each_with_index do |product, index|
      click_link "Refund"
      if index.positive?
        assert_text "Already refunded"
        assert_selector "input[aria-label='Refund #{products.first.name}'][disabled]"
      end
      find("input[aria-label='Refund #{product.name}']").check
      fill_in "Reason", with: "Usability regression return #{index + 1}"
      click_button "Process refund", exact: true
      within "[role='dialog']" do
        click_button "Process refund", exact: true
      end
      assert_current_path order_path(order)
      assert_text "processed."
      assert_equal initial_stock[index], product.reload.stock_level
    end
    assert order.reload.refunded?
    assert_equal order.total, order.refunds.sum(:total)
    visit refund_form_order_path(order)
    assert_current_path order_path(order)
    assert_text "All items on this order have already been refunded."
  end
end
