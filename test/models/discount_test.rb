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

  test "allowed_items scope returns only allowed discount_items" do
    discount = discounts(:fixed_per_item_specific)
    assert_equal 1, discount.allowed_items.count
    assert_includes discount.allowed_items, discount_items(:shield_red_on_per_item)
    assert_not_includes discount.allowed_items, discount_items(:shield_blue_denied)
  end

  test "denied_items scope returns only denied discount_items" do
    discount = discounts(:fixed_per_item_specific)
    assert_equal 1, discount.denied_items.count
    assert_includes discount.denied_items, discount_items(:shield_blue_denied)
    assert_not_includes discount.denied_items, discount_items(:shield_red_on_per_item)
  end

  test "per_item_discount? returns true for percentage and fixed_per_item" do
    assert discounts(:percentage_all).per_item_discount?
    assert discounts(:fixed_per_item_specific).per_item_discount?
    assert_not discounts(:fixed_total_specific).per_item_discount?
  end

  test "denies? returns false for order-level discounts (fixed_total)" do
    discount = discounts(:fixed_total_specific)
    product = products(:dragon_shield_blue)
    assert_not discount.denies?(product)
  end

  test "denies? returns true if product is in deny list" do
    discount = discounts(:fixed_per_item_specific)
    denied_product = products(:dragon_shield_blue)
    assert discount.denies?(denied_product)
  end

  test "denies? returns false if product is not in deny list" do
    discount = discounts(:fixed_per_item_specific)
    allowed_product = products(:dragon_shield_red)
    assert_not discount.denies?(allowed_product)
  end

  test "denies? returns true if product belongs to denied ProductGroup" do
    discount = discounts(:percentage_all)
    product = products(:dragon_shield_red)
    # dragon_shield_red is not in a product group, let's create a scenario
    # where a product is in the denied trading_cards group
    product.update!(product_group: product_groups(:trading_cards))
    assert discount.denies?(product)
  end

  test "allows? returns true if discount applies_to_all and item not denied" do
    discount = discounts(:percentage_all)
    product = products(:dragon_shield_red)
    assert discount.allows?(product)
  end

  test "allows? returns false if item is in deny list even if applies_to_all" do
    discount = discounts(:percentage_all)
    product = products(:dragon_shield_red)
    product.update!(product_group: product_groups(:trading_cards))
    assert_not discount.allows?(product)
  end

  test "allows? returns true if item is explicitly in allow list" do
    discount = discounts(:fixed_per_item_specific)
    allowed_product = products(:dragon_shield_red)
    assert discount.allows?(allowed_product)
  end

  test "allows? returns false if item not in allow list and not applies_to_all" do
    discount = discounts(:fixed_per_item_specific)
    nhl_puck = products(:nhl_puck)
    assert_not discount.allows?(nhl_puck)
  end
end
