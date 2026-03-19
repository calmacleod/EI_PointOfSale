# frozen_string_literal: true

require "test_helper"

class Products::BulkRestockServiceTest < ActiveSupport::TestCase
  setup do
    @user = users(:admin)
    @product1 = products(:dragon_shield_red)
    @product2 = products(:dragon_shield_blue)
  end

  test "restocks multiple products" do
    items = [
      { product_id: @product1.id, quantity: 10, notes: "Batch" },
      { product_id: @product2.id, quantity: 5, notes: nil }
    ]

    result = Products::BulkRestockService.call(items: items, user: @user)

    assert result.success?
    assert_equal 2, result.successes.size
    assert_empty result.failures
  end

  test "skips zero quantity items" do
    items = [
      { product_id: @product1.id, quantity: 10 },
      { product_id: @product2.id, quantity: 0 }
    ]

    result = Products::BulkRestockService.call(items: items, user: @user)

    assert result.success?
    assert_equal 1, result.successes.size
  end

  test "reports failure for missing product" do
    items = [
      { product_id: 999_999, quantity: 10 }
    ]

    result = Products::BulkRestockService.call(items: items, user: @user)

    assert_not result.success?
    assert_equal 1, result.failures.size
  end
end
