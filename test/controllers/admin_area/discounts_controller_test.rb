require "test_helper"

module AdminArea
  class DiscountsControllerTest < ActionDispatch::IntegrationTest
    setup do
      sign_in_as(users(:admin))
    end

    test "index lists discounts" do
      discount = discounts(:percentage_all)
      get admin_discounts_path
      assert_response :success
      assert_includes response.body, discount.name
    end

    test "show displays discount" do
      discount = discounts(:percentage_all)
      get admin_discount_path(discount)
      assert_response :success
      assert_includes response.body, discount.name
    end

    test "new renders form" do
      get new_admin_discount_path
      assert_response :success
      assert_includes response.body, "New discount"
    end

    test "create adds discount" do
      assert_difference("Discount.count", 1) do
        post admin_discounts_path, params: {
          discount: { name: "New Discount", discount_type: "percentage", value: 5, active: true, applies_to_all: false }
        }
      end
      assert_redirected_to admin_discount_path(Discount.last)
    end

    test "create with invalid params renders new" do
      assert_no_difference("Discount.count") do
        post admin_discounts_path, params: { discount: { name: "" } }
      end
      assert_response :unprocessable_entity
    end

    test "edit renders form" do
      discount = discounts(:percentage_all)
      get edit_admin_discount_path(discount)
      assert_response :success
      assert_includes response.body, discount.name
    end

    test "update modifies discount" do
      discount = discounts(:percentage_all)
      patch admin_discount_path(discount), params: {
        discount: { name: "Updated Name", discount_type: "percentage", value: 15, active: true, applies_to_all: true }
      }
      assert_redirected_to admin_discount_path(discount)
      assert_equal "Updated Name", discount.reload.name
    end

    test "destroy soft-deletes discount" do
      discount = discounts(:percentage_all)
      delete admin_discount_path(discount)
      assert_redirected_to admin_discounts_path
      assert discount.reload.discarded?
    end

    test "toggle_active flips active state" do
      discount = discounts(:percentage_all)
      assert discount.active?
      patch toggle_active_admin_discount_path(discount)
      assert_redirected_to admin_discount_path(discount)
      assert_not discount.reload.active?
    end

    test "search_items returns matching products" do
      get search_items_admin_discount_path(discounts(:fixed_total_specific)),
          params: { q: "Dragon", item_type: "Product" }
      assert_response :success
      assert_includes response.body, "Dragon Shield"
    end

    test "non-admin cannot access discounts" do
      sign_in_as(users(:one))
      get admin_discounts_path
      assert_redirected_to root_path
    end
  end
end
