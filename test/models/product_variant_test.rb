require "test_helper"

class ProductVariantTest < ActiveSupport::TestCase
  test "valid with product and code" do
    variant = ProductVariant.new(
      product: products(:dragon_shield),
      code: "TEST-001",
      selling_price: 10.00
    )
    assert variant.valid?
  end

  test "invalid without code" do
    variant = ProductVariant.new(
      product: products(:dragon_shield),
      code: nil
    )
    assert_not variant.valid?
  end

  test "invalid with duplicate code" do
    variant = ProductVariant.new(
      product: products(:simple_product),
      code: "DS-MAT-RED"
    )
    assert_not variant.valid?
  end

  test "belongs to product" do
    variant = product_variants(:ds_red)
    assert_equal products(:dragon_shield), variant.product
  end

  test "option_values stores variant attributes" do
    variant = product_variants(:ds_red)
    assert_equal "Red", variant.option_values["color"]
  end
end
