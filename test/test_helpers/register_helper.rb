# frozen_string_literal: true

module RegisterHelper
  # -- Actions --

  def fill_in_code_lookup(code)
    fill_in "code", with: code
    click_button "Add"
    assert_field "code", with: "", wait: 5
  end

  def fill_in_payment(method:, amount:, tendered: nil, gc_code: nil)
    within "#order_payments_panel" do
      click_button "Add Payment"
    end
    within "#payment_modal" do
      find("button[data-method='#{method}']").click
      assert_selector "button[data-method='#{method}'].bg-accent", wait: 5
      find("[name='order_payment[amount]']").set(amount.to_s)
      find("[name='order_payment[amount_tendered]']").set(tendered.to_s) if tendered
      find("[name='order_payment[reference]']").set(gc_code) if gc_code
      click_button "Record Payment"
    end
    # Wait for Turbo Stream to re-render the panel (modal closes, Add Payment reappears)
    within "#order_payments_panel", wait: 5 do
      assert_selector "button", text: "Add Payment", wait: 5
    end
  end

  def assign_customer(search_term)
    within "#order_customer_panel" do
      click_button "Search & assign customer"
    end
    assert_selector "#customer_search_modal:not(.hidden)", wait: 5
    within "#customer_search_modal" do
      fill_in placeholder: /search by name/i, with: search_term
    end
    assert_text search_term, wait: 5
    click_on search_term
    within "#order_customer_panel" do
      assert_text search_term, wait: 5
    end
  end

  def remove_customer
    within "#order_customer_panel" do
      find("button[type='submit']").click
    end
  end

  def apply_manual_discount(name:, type:, value:)
    within "#order_discounts_panel" do
      click_link "Add Discount"
    end
    assert_selector "turbo-frame#discount_modal", wait: 5
    fill_in "order_discount[name]", with: name
    select type, from: "order_discount[discount_type]"
    fill_in "order_discount[value]", with: value.to_s
    click_button "Apply Discount"
  end

  def open_payment_modal
    within "#order_payments_panel" do
      click_button "Add Payment"
    end
    assert_selector "#payment_modal", wait: 5
  end

  # -- Assertions --

  def assert_totals_panel(subtotal:, tax:, total:, discount: nil, remaining: nil, paid: nil)
    within "#order_totals" do
      assert_text format_currency(subtotal), wait: 5
      assert_text format_currency(tax)
      assert_text format_currency(total)
      assert_text format_currency(discount) if discount
      assert_text format_currency(remaining) if remaining
      assert_text format_currency(paid) if paid
    end
  end

  def assert_line_item(code:, name: nil, qty: nil, total: nil)
    within "#order_line_items" do
      assert_text code if code
      assert_text name if name
      assert_text qty.to_s if qty
      assert_text format_currency(total) if total
    end
  end

  def assert_no_line_items
    within "#order_line_items" do
      assert_text /no items/i
    end
  end

  def assert_empty_order_totals
    within "#order_totals" do
      assert_text "$0.00"
    end
  end

  private

    def format_currency(amount)
      "$#{format('%.2f', amount)}"
    end
end
