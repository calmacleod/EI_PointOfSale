# frozen_string_literal: true

require "test_helper"

class OrderDiscountTest < ActiveSupport::TestCase
  setup do
    @order = orders(:draft_order)
    @admin = users(:admin)
  end

  def build_discount(attrs = {})
    @order.order_discounts.build({
      name: "Test Discount",
      discount_type: :percentage,
      value: 10,
      scope: :all_items,
      applied_by: @admin
    }.merge(attrs))
  end

  # Validations
  test "requires name" do
    d = build_discount(name: nil)
    assert_not d.valid?
    assert_includes d.errors[:name], "can't be blank"
  end

  test "requires discount_type" do
    d = build_discount(discount_type: nil)
    assert_not d.valid?
  end

  test "requires value > 0" do
    d = build_discount(value: 0)
    assert_not d.valid?
    assert_includes d.errors[:value], "must be greater than 0"
  end

  test "is valid with proper attributes" do
    assert build_discount.valid?
  end

  # auto_applied?
  test "auto_applied? returns false when no discount_id" do
    d = build_discount
    d.discount_id = nil
    assert_not d.auto_applied?
  end

  test "auto_applied? returns true when discount_id is present" do
    d = build_discount
    d.discount = discounts(:percentage_all)
    assert d.auto_applied?
  end

  # display_value
  test "display_value formats percentage" do
    d = build_discount(discount_type: :percentage, value: 20)
    assert_equal "20%", d.display_value
  end

  test "display_value formats fixed_amount as currency" do
    d = build_discount(discount_type: :fixed_amount, value: 5)
    assert_equal "$5.00", d.display_value
  end

  test "display_value formats fixed_per_item as currency per item" do
    d = build_discount(discount_type: :fixed_per_item, value: 2)
    assert_equal "$2.00/item", d.display_value
  end
end
