# frozen_string_literal: true

require "test_helper"

class Orders::CalculateTotalsTest < ActiveSupport::TestCase
  setup do
    @order = orders(:draft_order)
    @product = products(:dragon_shield_red) # $14.99, 13% tax
  end

  test "computes subtotal and tax from lines" do
    line = @order.order_lines.build(quantity: 2)
    line.snapshot_from_sellable!(@product)
    line.position = 1
    line.save!

    Orders::CalculateTotals.call(@order)
    @order.reload

    assert_equal 29.98, @order.subtotal
    assert_equal 3.90, @order.tax_total
    assert_equal 33.88, @order.total
    assert_equal 0, @order.discount_total
  end

  test "applies customer tax code override" do
    exempt_tax = tax_codes(:two)
    customer = customers(:jane_doe)
    customer.update!(tax_code: exempt_tax)
    @order.update!(customer: customer)

    line = @order.order_lines.build(quantity: 1)
    line.snapshot_from_sellable!(@product)
    line.position = 1
    line.save!

    Orders::CalculateTotals.call(@order)
    @order.reload

    assert_equal 14.99, @order.subtotal
    assert_equal 0, @order.tax_total
    assert_equal 14.99, @order.total
  end

  test "order-level tax exemption applies to existing and new lines and restores tax when cleared" do
    first_line = @order.order_lines.build(quantity: 2, position: 1)
    first_line.snapshot_from_sellable!(@product)
    first_line.save!

    @order.order_discounts.create!(
      name: "10% Off",
      discount_type: :percentage,
      value: 10,
      scope: :all_items,
      applied_by: users(:admin)
    )

    @order.update!(tax_exempt: true)
    Orders::CalculateTotals.call(@order)

    assert_equal 0, first_line.reload.tax_rate
    assert_equal 0, @order.reload.tax_total
    assert_equal 26.98, @order.total
    assert_equal 3.0, @order.discount_total

    # A line added after the exemption is enabled starts with the product's
    # regular tax rate, so recalculation must apply the order-level override.
    second_line = @order.order_lines.build(quantity: 1, position: 2)
    second_line.snapshot_from_sellable!(products(:dragon_shield_blue))
    second_line.save!

    gift_certificate_line = @order.order_lines.build(quantity: 1, position: 3)
    gift_certificate_line.snapshot_from_sellable!(gift_certificates(:active_gc))
    gift_certificate_line.save!

    Orders::CalculateTotals.call(@order)
    @order.reload

    assert_equal 0, first_line.reload.tax_rate
    assert_equal 0, second_line.reload.tax_rate
    assert_equal 0, gift_certificate_line.reload.tax_rate
    assert_equal 0, @order.tax_total
    assert_equal 4.5, @order.discount_total
    assert_equal 140.47, @order.total

    @order.update!(tax_exempt: false)
    Orders::CalculateTotals.call(@order)
    @order.reload

    assert_equal 0.13, first_line.reload.tax_rate
    assert_equal 0.13, second_line.reload.tax_rate
    assert_equal 0, gift_certificate_line.reload.tax_rate
    assert_equal 5.85, @order.tax_total
    assert_equal 146.32, @order.total
  end

  test "distributes discount across lines" do
    line = @order.order_lines.build(quantity: 2)
    line.snapshot_from_sellable!(@product)
    line.position = 1
    line.save!

    @order.order_discounts.create!(
      name: "10% Off",
      discount_type: :percentage,
      value: 10,
      scope: :all_items,
      applied_by: users(:admin)
    )

    Orders::CalculateTotals.call(@order)
    @order.reload

    assert_equal 3.0, @order.discount_total
    assert @order.total < 33.88
  end

  test "reusing discount state removes deleted customer discounts from taxable amounts" do
    Discount.update_all(active: false)
    customer = customers(:discount_customer)
    @order.update!(customer: customer)
    line = @order.order_lines.build(quantity: 1, position: 1)
    line.snapshot_from_sellable!(@product)
    line.save!
    state = Discounts::AutoApply.call(@order)
    Orders::CalculateTotals.call(@order, state:)
    assert_operator @order.discount_total, :>, 0

    @order.update!(customer: nil)
    state = Discounts::AutoApply.call(@order)
    Orders::CalculateTotals.call(@order, state:)
    assert_equal 0, @order.discount_total
    assert_equal 1.95, @order.tax_total
    assert_equal 16.94, @order.total
  end
end
