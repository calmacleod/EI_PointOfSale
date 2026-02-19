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

    test "search_items returns all types when item_type is all" do
      # Add a product group to search against
      ProductGroup.create!(name: "Search Test Group")

      get search_items_admin_discount_path(discounts(:fixed_total_specific)),
          params: { q: "Dragon", item_type: "all" }
      assert_response :success
      assert_includes response.body, "Dragon Shield"
      assert_includes response.body, "Products"
    end

    test "search_items filters by exclusion_type" do
      discount = discounts(:fixed_per_item_specific)

      get search_items_admin_discount_path(discount),
          params: { q: "Blue", item_type: "Product", exclusion_type: "denied" }
      assert_response :success
    end

    test "bulk_add_items adds multiple items to allow list" do
      discount = discounts(:percentage_all)
      product = products(:nhl_puck)

      assert_difference "discount.discount_items.allowed.count", 1 do
        post bulk_add_items_admin_discount_path(discount), params: {
          exclusion_type: "allowed",
          discountable_ids: [ product.id ],
          discountable_types: [ "Product" ]
        }
      end

      assert_redirected_to admin_discount_path(discount)
      assert_equal "1 items added to allowed list.", flash[:notice]
    end

    test "bulk_add_items adds multiple items to deny list" do
      discount = discounts(:fixed_per_item_specific)
      product = products(:nhl_puck)

      assert_difference "discount.discount_items.denied.count", 1 do
        post bulk_add_items_admin_discount_path(discount), params: {
          exclusion_type: "denied",
          discountable_ids: [ product.id ],
          discountable_types: [ "Product" ]
        }
      end

      assert_redirected_to admin_discount_path(discount)
      assert_equal "1 items added to denied list.", flash[:notice]
    end

    test "bulk_add_items skips already added items" do
      discount = discounts(:fixed_per_item_specific)
      # dragon_shield_red is already in the allowed list
      existing_product = products(:dragon_shield_red)

      assert_no_difference "discount.discount_items.allowed.count" do
        post bulk_add_items_admin_discount_path(discount), params: {
          exclusion_type: "allowed",
          discountable_ids: [ existing_product.id ],
          discountable_types: [ "Product" ]
        }
      end

      assert_redirected_to admin_discount_path(discount)
      assert_equal "0 items added to allowed list.", flash[:notice]
    end

    test "non-admin cannot access discounts" do
      sign_in_as(users(:one))
      get admin_discounts_path
      assert_redirected_to root_path
    end
  end
end
