# frozen_string_literal: true

require "test_helper"

class OrderLineDiscountTest < ActiveSupport::TestCase
  setup do
    # Use a fresh order line to avoid unique constraint conflicts with other tests
    # that also create auto-applied discounts on fixtures like held_line.
    @admin = users(:admin)
    @order = Order.create!(created_by: @admin, status: :draft)
    @line = @order.order_lines.create!(
      sellable: products(:dragon_shield_red),
      code: "DS-MAT-RED",
      name: "Dragon Shield Red",
      quantity: 2,
      unit_price: 14.99,
      tax_rate: 0.13,
      tax_amount: 3.90,
      line_total: 33.88,
      position: 1
    )
    @discount = @line.order_line_discounts.create!(
      name: "10% Off Everything",
      discount_type: :percentage,
      value: 10.00,
      calculated_amount: 3.00,
      excluded_quantity: 0,
      auto_applied: true
    )
  end

  # Validations
  test "requires name" do
    @discount.name = nil
    assert_not @discount.valid?
    assert_includes @discount.errors[:name], "can't be blank"
  end

  test "requires discount_type" do
    @discount.discount_type = nil
    assert_not @discount.valid?
  end

  test "requires value >= 0" do
    @discount.value = -1
    assert_not @discount.valid?
    assert_includes @discount.errors[:value], "must be greater than or equal to 0"
  end

  test "allows value of 0" do
    @discount.value = 0
    @discount.calculated_amount = 0
    assert @discount.valid?
  end

  test "requires excluded_quantity >= 0" do
    @discount.excluded_quantity = -1
    assert_not @discount.valid?
  end

  # applied_quantity
  test "applied_quantity equals line quantity minus excluded_quantity" do
    @discount.excluded_quantity = 0
    assert_equal @line.quantity, @discount.applied_quantity
  end

  test "applied_quantity returns 0 when excluded_quantity equals line quantity" do
    @discount.excluded_quantity = @line.quantity
    assert_equal 0, @discount.applied_quantity
  end

  test "applied_quantity is never negative" do
    @discount.excluded_quantity = @line.quantity + 5
    assert_equal 0, @discount.applied_quantity
  end

  # fully_excluded? / active?
  test "fully_excluded? is false when discount applies to all units" do
    @discount.excluded_quantity = 0
    assert_not @discount.fully_excluded?
  end

  test "fully_excluded? is true when excluded_quantity equals line quantity" do
    @discount.excluded_quantity = @line.quantity
    assert @discount.fully_excluded?
  end

  test "active? is true when applied_quantity > 0" do
    @discount.excluded_quantity = 0
    assert @discount.active?
  end

  test "active? is false when fully excluded" do
    @discount.excluded_quantity = @line.quantity
    assert_not @discount.active?
  end

  # Mutation methods
  test "exclude_one! increments excluded_quantity by 1" do
    initial = @discount.excluded_quantity
    @discount.exclude_one!
    assert_equal initial + 1, @discount.reload.excluded_quantity
  end

  test "exclude_one! is a no-op when already fully excluded" do
    @discount.update!(excluded_quantity: @line.quantity)
    @discount.exclude_one!
    assert_equal @line.quantity, @discount.reload.excluded_quantity
  end

  test "restore_one! decrements excluded_quantity by 1" do
    @discount.update!(excluded_quantity: 1)
    @discount.restore_one!
    assert_equal 0, @discount.reload.excluded_quantity
  end

  test "restore_one! is a no-op when excluded_quantity is already 0" do
    @discount.update!(excluded_quantity: 0)
    @discount.restore_one!
    assert_equal 0, @discount.reload.excluded_quantity
  end

  test "exclude_all! sets excluded_quantity to line quantity" do
    @discount.update!(excluded_quantity: 0)
    @discount.exclude_all!
    assert_equal @line.quantity, @discount.reload.excluded_quantity
  end

  test "restore_all! sets excluded_quantity to 0" do
    @discount.update!(excluded_quantity: @line.quantity)
    @discount.restore_all!
    assert_equal 0, @discount.reload.excluded_quantity
  end

  # display_value
  test "display_value formats percentage" do
    @discount.discount_type = :percentage
    @discount.value = 15
    assert_equal "15%", @discount.display_value
  end

  test "display_value formats fixed_amount as currency" do
    @discount.discount_type = :fixed_amount
    @discount.value = 5
    assert_equal "$5.00", @discount.display_value
  end

  test "display_value formats fixed_per_item as currency per item" do
    @discount.discount_type = :fixed_per_item
    @discount.value = 2
    assert_equal "$2.00/item", @discount.display_value
  end

  # Scopes
  test "auto_applied scope returns auto-applied discounts" do
    assert_includes OrderLineDiscount.auto_applied, @discount
  end

  test "manual scope excludes auto-applied discounts" do
    assert_not_includes OrderLineDiscount.manual, @discount
  end
end
