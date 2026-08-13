# frozen_string_literal: true

require "test_helper"

class SearchControllerTest < ActionDispatch::IntegrationTest
  test "search requires authentication" do
    get search_path(q: "test")
    assert_redirected_to new_session_path
  end

  test "signed in user can search and gets JSON results" do
    sign_in_as(users(:one))
    PgSearch::Multisearch.rebuild(Product)
    product = products(:dragon_shield_red)

    get search_path(q: "Dragon", format: :json)

    assert_response :success
    data = JSON.parse(response.body)
    assert data["results"].is_a?(Array)
    product_result = data["results"].find { |r| r["type"] == "Product" && r["label"]&.include?("Dragon") }
    assert product_result, "Expected to find product in results: #{data['results'].inspect}"
    assert product_result["url"].present?
    assert_equal "product", product_result["icon"]
  end

  test "empty query returns best-selling items" do
    sign_in_as(users(:one))
    products(:dragon_shield_red).update_column(:sales_count, 10)

    get search_path(q: "", format: :json)

    assert_response :success
    data = JSON.parse(response.body)
    assert data["results"].any?, "Expected best-selling items for empty query"
    assert_equal "Product", data["results"].first["type"]
  end

  test "non-empty query returns array of results" do
    sign_in_as(users(:one))

    get search_path(q: "xyz_nonexistent_123", format: :json)

    assert_response :success
    data = JSON.parse(response.body)
    assert data["results"].is_a?(Array)
    assert data["results"].empty?, "Expected no matches for nonsense query"
  end

  test "exact product code match appears first in results" do
    sign_in_as(users(:one))
    product = products(:dragon_shield_red)

    get search_path(q: product.code, format: :json)

    assert_response :success
    data = JSON.parse(response.body)
    first = data["results"].first
    assert first, "Expected at least one result for exact code"
    assert_equal "Product", first["type"]
  end

  test "exact service code match appears first in results" do
    sign_in_as(users(:one))
    service = Service.create!(name: "Barcode Test Service", code: "SVC-EXACT-001", price: 10.00)

    get search_path(q: "SVC-EXACT-001", format: :json)

    assert_response :success
    data = JSON.parse(response.body)
    first = data["results"].first
    assert first, "Expected at least one result for exact service code"
    assert_equal "Service", first["type"]
  end
end
