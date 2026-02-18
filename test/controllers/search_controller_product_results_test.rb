# frozen_string_literal: true

require "test_helper"

class SearchControllerProductResultsTest < ActionDispatch::IntegrationTest
  test "product_results returns HTML response" do
    sign_in_as(users(:admin))
    get product_results_search_path, params: { q: "test", limit: 10, selected: 0 }
    assert_response :success
    assert_includes response.content_type, "text/html"
  end

  test "product_results returns empty results message when no matches" do
    sign_in_as(users(:admin))
    get product_results_search_path, params: { q: "xyznonexistent12345", limit: 10, selected: 0 }
    assert_response :success
    assert_match /No products or services found/, response.body
  end

  test "product_results returns empty results for blank query" do
    sign_in_as(users(:admin))
    get product_results_search_path, params: { q: "", limit: 10, selected: 0 }
    assert_response :success
    # Empty query returns empty results HTML
    assert_match /No products or services found/, response.body
  end

  test "product_results accepts type filter parameter" do
    sign_in_as(users(:admin))
    get product_results_search_path, params: { q: "test", type: "Product", limit: 10, selected: 0 }
    assert_response :success
  end
end
