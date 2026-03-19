# frozen_string_literal: true

require "test_helper"

class Products::RestockServiceTest < ActiveSupport::TestCase
  setup do
    @product = products(:dragon_shield_red)
    @user = users(:admin)
  end

  test "successfully restocks product" do
    original_stock = @product.stock_level

    result = Products::RestockService.call(product: @product, quantity: 10, user: @user)

    assert result.success?
    assert_equal original_stock + 10, @product.reload.stock_level
    assert_equal original_stock + 10, result.restock.stock_level_after
    assert_equal 10, result.restock.quantity
    assert_equal @user, result.restock.user
  end

  test "creates restock record" do
    assert_difference "Restock.count", 1 do
      Products::RestockService.call(product: @product, quantity: 5, user: @user, notes: "Test restock")
    end
  end

  test "saves notes" do
    result = Products::RestockService.call(product: @product, quantity: 5, user: @user, notes: "From supplier")
    assert_equal "From supplier", result.restock.notes
  end

  test "rejects zero quantity" do
    result = Products::RestockService.call(product: @product, quantity: 0, user: @user)

    assert_not result.success?
    assert_includes result.errors, "Quantity must be greater than 0"
  end

  test "rejects negative quantity" do
    result = Products::RestockService.call(product: @product, quantity: -5, user: @user)

    assert_not result.success?
    assert_includes result.errors, "Quantity must be greater than 0"
  end

  test "does not change stock on failure" do
    original_stock = @product.stock_level
    Products::RestockService.call(product: @product, quantity: 0, user: @user)
    assert_equal original_stock, @product.reload.stock_level
  end
end
