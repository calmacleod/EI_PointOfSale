require "test_helper"

class ProductGroupTest < ActiveSupport::TestCase
  test "valid with name" do
    group = ProductGroup.new(name: "Dragon Shield Matte Sleeves")
    assert group.valid?
  end

  test "invalid without name" do
    group = ProductGroup.new(name: nil)
    assert_not group.valid?
    assert_includes group.errors[:name], "can't be blank"
  end

  test "has many products" do
    group = ProductGroup.create!(name: "Test Group")
    product = products(:dragon_shield_red)
    product.update!(product_group: group)

    assert_includes group.products, product
  end

  test "nullifies products on destroy" do
    group = ProductGroup.create!(name: "To Destroy")
    product = products(:dragon_shield_red)
    product.update!(product_group: group)

    group.destroy
    assert_nil product.reload.product_group_id
  end
end
