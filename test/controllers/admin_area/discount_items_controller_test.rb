# frozen_string_literal: true

require "test_helper"

module AdminArea
  class DiscountItemsControllerTest < ActionDispatch::IntegrationTest
    setup do
      sign_in_as(users(:admin))
      @discount = discounts(:fixed_total_specific)
    end

    test "create adds product discount item" do
      product = products(:nhl_puck)

      assert_difference("@discount.discount_items.count", 1) do
        post admin_discount_discount_items_path(@discount), params: {
          discountable_type: "Product",
          discountable_id: product.id
        }
      end

      assert_redirected_to admin_discount_path(@discount)
      assert @discount.discount_items.exists?(discountable: product)
    end

    test "create adds service discount item" do
      service = services(:printer_refill)

      assert_difference("@discount.discount_items.count", 1) do
        post admin_discount_discount_items_path(@discount), params: {
          discountable_type: "Service",
          discountable_id: service.id
        }
      end

      assert_redirected_to admin_discount_path(@discount)
      assert @discount.discount_items.exists?(discountable: service)
    end

    test "create rejects unknown discountable types" do
      assert_raises(ArgumentError) do
        post admin_discount_discount_items_path(@discount), params: {
          discountable_type: "ProductGroup",
          discountable_id: product_groups(:gaming_supplies).id
        }
      end
    end

    test "destroy removes discount item" do
      item = discount_items(:shield_red_on_fixed_total)

      assert_difference("DiscountItem.count", -1) do
        delete admin_discount_item_path(item)
      end

      assert_redirected_to admin_discount_path(item.discount)
    end

    test "non-admin cannot create discount item" do
      sign_in_as(users(:one))
      product = products(:nhl_puck)

      assert_no_difference("DiscountItem.count") do
        post admin_discount_discount_items_path(@discount), params: {
          discountable_type: "Product",
          discountable_id: product.id
        }
      end

      assert_redirected_to root_path
    end
  end
end
