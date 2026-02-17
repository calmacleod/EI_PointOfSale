require "test_helper"

class DiscountTest < ActiveSupport::TestCase
  test "valid with required attributes" do
    discount = Discount.new(name: "Test", discount_type: :percentage, value: 10)
    assert discount.valid?
  end

  test "requires name" do
    discount = Discount.new(discount_type: :percentage, value: 10)
    assert_not discount.valid?
    assert_includes discount.errors[:name], "can't be blank"
  end

  test "requires value greater than zero" do
    discount = Discount.new(name: "Test", discount_type: :percentage, value: 0)
    assert_not discount.valid?
    assert_includes discount.errors[:value], "must be greater than 0"
  end

  test "currently_active scope returns active discounts in date range" do
    active = discounts(:percentage_all)
    inactive = discounts(:inactive_discount)
    future = discounts(:future_discount)
    expired = discounts(:expired_discount)

    result = Discount.currently_active
    assert_includes result, active
    assert_not_includes result, inactive
    assert_not_includes result, future
    assert_not_includes result, expired
  end

  test "display_value formats percentage" do
    discount = Discount.new(discount_type: :percentage, value: 10)
    assert_equal "10%", discount.display_value
  end

  test "display_value formats fixed_total" do
    discount = Discount.new(discount_type: :fixed_total, value: 5.00)
    assert_includes discount.display_value, "5"
  end

  test "display_value formats fixed_per_item" do
    discount = Discount.new(discount_type: :fixed_per_item, value: 1.00)
    assert_includes discount.display_value, "/item"
  end

  test "soft delete with discard" do
    discount = discounts(:percentage_all)
    discount.discard
    assert discount.discarded?
    assert_not_includes Discount.kept, discount
  end

  test "has_many discount_items" do
    discount = discounts(:fixed_total_specific)
    assert_equal 1, discount.discount_items.count
  end
end
