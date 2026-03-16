# frozen_string_literal: true

require "test_helper"

class Orders::GenerateReceiptTest < ActiveSupport::TestCase
  setup do
    @order = orders(:completed_order)
    @lines = Orders::GenerateReceipt.call(@order)
  end

  test "returns an array of strings" do
    assert_kind_of Array, @lines
    assert @lines.all? { |l| l.is_a?(String) }, "Expected all elements to be strings"
  end

  test "includes the store name in the header" do
    store = Store.current
    if store&.name.present? && ReceiptTemplate.current&.show_store_name
      assert @lines.any? { |l| l.include?(store.name.upcase) },
             "Expected store name '#{store.name}' to appear in receipt"
    end
  end

  test "includes the order number" do
    assert @lines.any? { |l| l.include?(@order.number) },
           "Expected order number '#{@order.number}' to appear in receipt"
  end

  test "includes line item names" do
    @order.order_lines.each do |line|
      assert @lines.any? { |l| l.include?(line.name) },
             "Expected line item '#{line.name}' to appear in receipt"
    end
  end

  test "includes the subtotal" do
    subtotal_formatted = "$#{'%.2f' % @order.subtotal}"
    assert @lines.any? { |l| l.include?(subtotal_formatted) },
           "Expected subtotal '#{subtotal_formatted}' in receipt"
  end

  test "includes the total" do
    total_formatted = "$#{'%.2f' % @order.total}"
    assert @lines.any? { |l| l.include?(total_formatted) },
           "Expected total '#{total_formatted}' in receipt"
  end

  test "includes payment method names" do
    @order.order_payments.each do |payment|
      assert @lines.any? { |l| l.include?(payment.display_method) },
             "Expected payment method '#{payment.display_method}' in receipt"
    end
  end

  test "shows tendered and change for cash payments" do
    cash_payment = @order.order_payments.find_by(payment_method: :cash)
    if cash_payment&.amount_tendered.present?
      assert @lines.any? { |l| l.include?("Tendered") },
             "Expected 'Tendered' in receipt for cash payment"
      assert @lines.any? { |l| l.include?("Change") },
             "Expected 'Change' in receipt for cash payment"
    end
  end

  test "includes footer text from receipt template" do
    template = ReceiptTemplate.current
    if template&.footer_text.present?
      # Use a short prefix to avoid truncation/ellipsis issues with centering
      footer_fragment = template.footer_text.lines.first.strip.first(15)
      assert @lines.any? { |l| l.include?(footer_fragment) },
             "Expected footer text fragment '#{footer_fragment}' in receipt"
    end
  end

  test "includes tax exempt notice for tax exempt order" do
    @order.update_column(:tax_exempt, true)
    lines = Orders::GenerateReceipt.call(@order.reload)
    assert lines.any? { |l| l.include?("TAX EXEMPT") },
           "Expected TAX EXEMPT notice in receipt for tax exempt order"
  end
end
