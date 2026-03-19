# frozen_string_literal: true

require "test_helper"

class RestockTest < ActiveSupport::TestCase
  test "valid restock" do
    restock = Restock.new(
      product: products(:dragon_shield_red),
      user: users(:admin),
      quantity: 10,
      stock_level_after: 34
    )
    assert restock.valid?
  end

  test "requires quantity greater than zero" do
    restock = Restock.new(
      product: products(:dragon_shield_red),
      user: users(:admin),
      quantity: 0,
      stock_level_after: 24
    )
    assert_not restock.valid?
    assert_includes restock.errors[:quantity], "must be greater than 0"
  end

  test "requires negative quantity is invalid" do
    restock = Restock.new(
      product: products(:dragon_shield_red),
      user: users(:admin),
      quantity: -5,
      stock_level_after: 24
    )
    assert_not restock.valid?
  end

  test "requires stock_level_after" do
    restock = Restock.new(
      product: products(:dragon_shield_red),
      user: users(:admin),
      quantity: 10,
      stock_level_after: nil
    )
    assert_not restock.valid?
    assert_includes restock.errors[:stock_level_after], "can't be blank"
  end

  test "belongs to product" do
    restock = restocks(:recent_restock)
    assert_equal products(:dragon_shield_red), restock.product
  end

  test "belongs to user" do
    restock = restocks(:recent_restock)
    assert_equal users(:admin), restock.user
  end
end
