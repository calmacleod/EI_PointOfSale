require "test_helper"

class CategoryTest < ActiveSupport::TestCase
  test "valid with name" do
    category = Category.new(name: "Test Category")
    assert category.valid?
  end

  test "invalid without name" do
    category = Category.new(name: nil)
    assert_not category.valid?
  end

  test "has categorizations" do
    category = categories(:card_sleeves)
    assert_respond_to category, :categorizations
  end
end
