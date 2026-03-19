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

  test "signed in user can search and gets turbo stream results" do
    sign_in_as(users(:one))
    PgSearch::Multisearch.rebuild(Product)
    product = products(:dragon_shield_red)

    get search_path(q: "Dragon"),
        headers: { "Accept" => "text/vnd.turbo-stream.html" }

    assert_response :success
    assert_equal "text/vnd.turbo-stream.html", response.media_type
    assert_includes response.body, "search_results"
    assert_includes response.body, product.name
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

  test "product_results empty query returns best-selling items" do
    sign_in_as(users(:one))
    products(:dragon_shield_red).update_column(:sales_count, 10)
    products(:dragon_shield_blue).update_column(:sales_count, 5)

    get product_results_search_path(q: "")

    assert_response :success
    assert_includes response.body, products(:dragon_shield_red).name
    assert_includes response.body, products(:dragon_shield_blue).name
  end

  test "product_results fuzzy results sorted by sales_count descending" do
    sign_in_as(users(:one))
    PgSearch::Multisearch.rebuild(Product)

    # Blue has higher sales_count, should appear first
    products(:dragon_shield_blue).update_column(:sales_count, 100)
    products(:dragon_shield_red).update_column(:sales_count, 5)

    get product_results_search_path(q: "Dragon Shield")

    assert_response :success
    body = response.body
    blue_pos = body.index(products(:dragon_shield_blue).name)
    red_pos = body.index(products(:dragon_shield_red).name)
    assert blue_pos, "Expected Blue to appear in results"
    assert red_pos, "Expected Red to appear in results"
    assert blue_pos < red_pos, "Expected Blue (higher sales_count) to appear before Red"
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
