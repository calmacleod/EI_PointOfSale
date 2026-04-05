# frozen_string_literal: true

require "test_helper"

class Api::V1::CustomersControllerTest < ActionDispatch::IntegrationTest
  setup do
    @customer = customers(:jane_doe)
  end

  test "sync requires authentication" do
    get api_v1_customers_sync_path, as: :json

    assert_response :redirect
  end

  test "sync returns all active customers as JSON" do
    sign_in_as(users(:admin))

    get api_v1_customers_sync_path, as: :json

    assert_response :success
    body = response.parsed_body
    assert body.key?("synced_at")
    assert body.key?("customers")
    assert body["customers"].is_a?(Array)

    customer_data = body["customers"].find { |c| c["id"] == @customer.id }
    assert_not_nil customer_data
    assert_equal @customer.name, customer_data["name"]
    assert customer_data.key?("member_number")
    assert customer_data.key?("email")
    assert customer_data.key?("phone")
    assert customer_data.key?("updated_at")
  end

  test "sync works for common users" do
    sign_in_as(users(:one))

    get api_v1_customers_sync_path, as: :json

    assert_response :success
  end

  test "sync with since param returns only updated customers" do
    sign_in_as(users(:admin))
    future = 1.year.from_now.iso8601

    get api_v1_customers_sync_path, params: { since: future }, as: :json

    assert_response :success
    body = response.parsed_body
    assert_empty body["customers"]
  end

  test "sync with invalid since param returns all customers" do
    sign_in_as(users(:admin))

    get api_v1_customers_sync_path, params: { since: "not-a-date" }, as: :json

    assert_response :success
    body = response.parsed_body
    assert body["customers"].any?
  end
end
