# frozen_string_literal: true

require "test_helper"

class FiltersControllerTest < ActionDispatch::IntegrationTest
  test "chip action renders filter chip for products association filter" do
    sign_in_as(users(:admin))
    get filter_chip_path, params: { resource: "products", key: "supplier_id", form_id: "products_filter_form" }
    assert_response :success
    assert_select "[data-filter-key='supplier_id']"
    assert_select "select[name='supplier_id']"
  end

  test "chip action renders filter chip for products boolean filter" do
    sign_in_as(users(:admin))
    get filter_chip_path, params: { resource: "products", key: "sync_to_shopify", form_id: "products_filter_form" }
    assert_response :success
    assert_select "[data-filter-key='sync_to_shopify']"
    assert_select "select[name='sync_to_shopify']"
  end

  test "chip action renders filter chip for products number_range filter" do
    sign_in_as(users(:admin))
    get filter_chip_path, params: { resource: "products", key: "selling_price", form_id: "products_filter_form" }
    assert_response :success
    assert_select "[data-filter-key='selling_price']"
    assert_select "input[name='selling_price_min']"
    assert_select "input[name='selling_price_max']"
  end

  test "chip action renders filter chip for products date_range filter" do
    sign_in_as(users(:admin))
    get filter_chip_path, params: { resource: "products", key: "created_at", form_id: "products_filter_form" }
    assert_response :success
    assert_select "[data-filter-key='created_at']"
    assert_select "select[name='created_at_preset']"
  end

  test "chip action renders filter chip for products multi_select filter" do
    sign_in_as(users(:admin))
    get filter_chip_path, params: { resource: "products", key: "category_ids", form_id: "products_filter_form" }
    assert_response :success
    assert_select "[data-filter-key='category_ids']"
    assert_select "input[type='checkbox'][name='category_ids[]']"
  end

  test "chip action returns 404 for unknown resource" do
    sign_in_as(users(:admin))
    get filter_chip_path, params: { resource: "unknown", key: "foo", form_id: "test_form" }
    assert_response :not_found
  end

  test "chip action returns 404 for unknown filter key" do
    sign_in_as(users(:admin))
    get filter_chip_path, params: { resource: "products", key: "unknown_key", form_id: "test_form" }
    assert_response :not_found
  end
end
