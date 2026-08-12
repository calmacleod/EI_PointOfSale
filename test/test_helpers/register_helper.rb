# frozen_string_literal: true

module RegisterHelper
  # -- Actions --

  def fill_in_code_lookup(code)
    fill_in "code", with: code
    click_button "Add"
    assert_field "code", with: "", wait: 5
  end

  def fill_in_payment(method:, amount:, tendered: nil, gc_code: nil)
    payment_count = all("#order_payments_panel [data-payment-id]").size
    within "#order_payments_panel" do
      select method.humanize, from: "Payment method"
      fill_in "Payment amount", with: amount.to_s
      fill_in "Amount tendered", with: tendered.to_s if tendered
      fill_in "Reference", with: gc_code if gc_code
      click_button "Add payment"
    end
    assert_selector "#order_payments_panel [data-payment-id]", count: payment_count + 1, wait: 5
  end

  def assign_customer(search_term)
    within "#order_customer_panel" do
      fill_in "Search customer", with: search_term
    end
    assert_text search_term, wait: 5
    click_on search_term
    within "#order_customer_panel" do
      assert_no_field "Search customer", wait: 5
      assert_text search_term, wait: 5
    end
  end

  def remove_customer
    within "#order_customer_panel" do
      click_button "Remove"
    end
  end

  def apply_manual_discount(name:, type:, value:)
    within "#order_discounts_panel" do
      find("summary", text: /add discount/i).click
      fill_in "Discount name", with: name
      select type, from: "Discount type"
      fill_in "Discount value", with: value.to_s
      click_button "Apply discount"
    end
  end

  def issue_gift_certificate(amount)
    find("summary", text: /issue gift certificate/i).click
    fill_in "Gift certificate amount", with: amount.to_s
    click_button "Add to order"
    assert_text "Gift Certificate", wait: 5
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
