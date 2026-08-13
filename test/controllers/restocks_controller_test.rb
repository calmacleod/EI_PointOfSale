# frozen_string_literal: true

require "test_helper"

class RestocksControllerTest < ActionDispatch::IntegrationTest
  setup do
    @product = products(:dragon_shield_red)
  end

  test "admin can view restock history" do
    sign_in_as(users(:admin))
    get product_restocks_path(@product)
    assert_response :success
    assert_equal "Restock History", inertia_props["title"]
    assert_equal "operations", inertia_props["view"]
    assert_equal product_restocks_path(@product), inertia_props["pagination_path"]
    assert_equal 2, inertia_props.dig("pagination", "count")
  end

  test "restock history paginates beyond the first 20 records" do
    21.times do |index|
      @product.restocks.create!(user: users(:admin), quantity: 1, stock_level_after: 35 + index)
    end

    sign_in_as(users(:admin))
    get product_restocks_path(@product, page: 2)

    assert_response :success
    assert_equal 2, inertia_props.dig("pagination", "page")
    assert_equal 3, inertia_props["details"].length
  end

  test "common user can view restock history" do
    sign_in_as(users(:one))
    get product_restocks_path(@product)
    assert_response :success
  end

  test "unauthenticated user cannot view restock history" do
    get product_restocks_path(@product)
    assert_response :redirect
  end
end
