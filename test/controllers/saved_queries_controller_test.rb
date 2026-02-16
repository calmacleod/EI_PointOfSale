# frozen_string_literal: true

require "test_helper"

class SavedQueriesControllerTest < ActionDispatch::IntegrationTest
  setup do
    @user = users(:one)
    post session_url, params: { email_address: @user.email_address, password: "password" }
  end

  test "create saves a query for the current user" do
    assert_difference "SavedQuery.count", 1 do
      post saved_queries_url, params: {
        saved_query: {
          name: "My filter",
          resource_type: "products",
          query_params: { q: "dragon", supplier_id: "1" }
        }
      }
    end

    query = SavedQuery.last
    assert_equal "My filter", query.name
    assert_equal "products", query.resource_type
    assert_equal @user.id, query.user_id
    assert_equal({ "q" => "dragon", "supplier_id" => "1" }, query.query_params)
  end

  test "create rejects blank name" do
    assert_no_difference "SavedQuery.count" do
      post saved_queries_url, params: {
        saved_query: {
          name: "",
          resource_type: "products",
          query_params: {}
        }
      }
    end
  end

  test "destroy removes the saved query" do
    query = saved_queries(:product_filter)

    assert_difference "SavedQuery.count", -1 do
      delete saved_query_url(query)
    end
  end

  test "cannot destroy another user's saved query" do
    query = saved_queries(:admin_filter)

    assert_no_difference "SavedQuery.count" do
      delete saved_query_url(query)
    end

    # Should get 404 since scoped find won't find another user's record
    assert_response :not_found
  end

  test "requires authentication" do
    delete session_url
    post saved_queries_url, params: {
      saved_query: { name: "Test", resource_type: "products", query_params: {} }
    }
    assert_redirected_to new_session_url
  end
end
