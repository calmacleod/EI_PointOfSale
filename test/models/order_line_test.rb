# frozen_string_literal: true

require "test_helper"

class OrderLineTest < ActiveSupport::TestCase
  test "calculates line total from unit_price and quantity" do
    order = orders(:draft_order)
    product = products(:dragon_shield_red)

    line = order.order_lines.build(quantity: 3)
    line.snapshot_from_sellable!(product)
    line.save!

    assert_equal 14.99, line.unit_price
    expected_subtotal = (14.99 * 3)
    assert_equal expected_subtotal, line.subtotal_before_discount
  end

  test "snapshots sellable data" do
    order = orders(:draft_order)
    product = products(:dragon_shield_red)

    line = order.order_lines.build(quantity: 1)
    line.snapshot_from_sellable!(product)

    assert_equal "DS-MAT-RED", line.code
    assert_equal "Dragon Shield Matte Sleeves - Red", line.name
    assert_equal 14.99, line.unit_price
    assert_equal 0.13, line.tax_rate
  end

  test "applies customer tax code override" do
    order = orders(:draft_order)
    product = products(:dragon_shield_red)
    exempt_tax = tax_codes(:two) # EXEMPT, rate 0

    line = order.order_lines.build(quantity: 1)
    line.snapshot_from_sellable!(product, customer_tax_code: exempt_tax)

    assert_equal 0, line.tax_rate
    assert_equal exempt_tax, line.tax_code
  end

  test "validates quantity greater than zero" do
    line = OrderLine.new(quantity: 0)
    assert_not line.valid?
    assert_includes line.errors[:quantity], "must be greater than 0"
  end
end
