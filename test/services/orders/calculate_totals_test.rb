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
end
