require "test_helper"

class ProductTest < ActiveSupport::TestCase
  test "valid with code and name" do
    product = Product.new(
      code: "TEST-001",
      name: "Test Product",
      selling_price: 9.99,
      tax_code: tax_codes(:one),
      supplier: suppliers(:jf_sports),
      added_by: users(:admin)
    )
    assert product.valid?
  end

  test "invalid without name" do
    product = Product.new(code: "TEST-001", name: nil)
    assert_not product.valid?
    assert_includes product.errors[:name], "can't be blank"
  end

  test "invalid without code" do
    product = Product.new(name: "Test", code: nil)
    assert_not product.valid?
    assert_includes product.errors[:code], "can't be blank"
  end

  test "invalid with duplicate code" do
    product = Product.new(
      code: "DS-MAT-RED",
      name: "Duplicate"
    )
    assert_not product.valid?
    assert_includes product.errors[:code], "has already been taken"
  end

  test "has categories through categorizations" do
    product = products(:dragon_shield_red)
    assert product.categories.any?
  end

  test "discards" do
    product = products(:nhl_puck)
    product.discard
    assert product.discarded?
  end

  test "find_by_exact_code returns kept product" do
    product = products(:dragon_shield_red)
    assert_equal product, Product.find_by_exact_code("DS-MAT-RED")
  end

  test "find_by_exact_code returns nil for discarded product" do
    product = products(:dragon_shield_red)
    product.discard
    assert_nil Product.find_by_exact_code("DS-MAT-RED")
  end

  test "find_by_exact_code strips whitespace" do
    product = products(:dragon_shield_red)
    assert_equal product, Product.find_by_exact_code("  DS-MAT-RED  ")
  end

  test "belongs to optional product_group" do
    product = products(:dragon_shield_red)
    assert_nil product.product_group

    group = ProductGroup.create!(name: "Dragon Shield Matte Sleeves")
    product.update!(product_group: group)
    assert_equal group, product.reload.product_group
  end

  test "can attach images" do
    product = products(:dragon_shield_red)
    product.images.attach(
      io: File.open(Rails.root.join("test/fixtures/files/test_image.png")),
      filename: "test_image.png",
      content_type: "image/png"
    )
    assert product.images.attached?
    assert_equal 1, product.images.count
  end

  test "can attach multiple images" do
    product = products(:dragon_shield_red)
    2.times do |i|
      product.images.attach(
        io: File.open(Rails.root.join("test/fixtures/files/test_image.png")),
        filename: "test_image_#{i}.png",
        content_type: "image/png"
      )
    end
    assert_equal 2, product.images.count
  end
end
