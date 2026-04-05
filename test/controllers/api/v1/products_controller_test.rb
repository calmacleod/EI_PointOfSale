# frozen_string_literal: true

require "test_helper"

class Api::V1::ProductsControllerTest < ActionDispatch::IntegrationTest
  setup do
    @product = products(:dragon_shield_red)
  end

  test "sync requires authentication" do
    get api_v1_products_sync_path, as: :json

    assert_response :redirect
  end

  test "sync returns all active products as JSON" do
    sign_in_as(users(:admin))

    get api_v1_products_sync_path, as: :json

    assert_response :success
    body = response.parsed_body
    assert body.key?("synced_at")
    assert body.key?("products")
    assert body["products"].is_a?(Array)

    product_data = body["products"].find { |p| p["id"] == @product.id }
    assert_not_nil product_data
    assert_equal @product.code, product_data["code"]
    assert_equal @product.name, product_data["name"]
    assert_equal @product.selling_price.to_s, product_data["selling_price"]
    assert product_data.key?("stock_level")
    assert product_data.key?("tax_code")
    assert product_data.key?("tax_rate")
    assert product_data.key?("updated_at")
  end

  test "sync works for common users" do
    sign_in_as(users(:one))

    get api_v1_products_sync_path, as: :json

    assert_response :success
  end

  test "sync with since param returns only updated products" do
    sign_in_as(users(:admin))
    future = 1.year.from_now.iso8601

    get api_v1_products_sync_path, params: { since: future }, as: :json

    assert_response :success
    body = response.parsed_body
    assert_empty body["products"]
  end

  test "sync with invalid since param returns all products" do
    sign_in_as(users(:admin))

    get api_v1_products_sync_path, params: { since: "not-a-date" }, as: :json

    assert_response :success
    body = response.parsed_body
    assert body["products"].any?
  end
end
