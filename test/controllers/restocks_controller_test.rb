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
    assert_includes response.body, "Restock History"
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
