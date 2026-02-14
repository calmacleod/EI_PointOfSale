require "test_helper"

class CategorizationTest < ActiveSupport::TestCase
  test "belongs to categorizable polymorphic" do
    cat = categorizations(:product_card_sleeves)
    assert_equal products(:dragon_shield), cat.categorizable
  end

  test "belongs to category" do
    cat = categorizations(:product_card_sleeves)
    assert_equal categories(:card_sleeves), cat.category
  end

  test "service categorization" do
    cat = categorizations(:service_cat)
    assert_equal services(:printer_refill), cat.categorizable
    assert_equal categories(:services), cat.category
  end
end
