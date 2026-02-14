require "test_helper"

class ProductTest < ActiveSupport::TestCase
  test "valid with name" do
    product = Product.new(
      name: "Test Product",
      tax_code: tax_codes(:one),
      supplier: suppliers(:jf_sports),
      added_by: users(:admin)
    )
    assert product.valid?
  end

  test "invalid without name" do
    product = Product.new(name: nil)
    assert_not product.valid?
  end

  test "has many variants" do
    product = products(:dragon_shield)
    assert product.variants.any?
    assert_includes product.variants.map(&:code), "DS-MAT-RED"
  end

  test "has categories through categorizations" do
    product = products(:dragon_shield)
    assert product.categories.any?
  end

  test "discards" do
    product = products(:simple_product)
    product.discard
    assert product.discarded?
  end
end
