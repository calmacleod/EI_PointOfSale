# frozen_string_literal: true

require "test_helper"

class Api::V1::ServicesControllerTest < ActionDispatch::IntegrationTest
  setup do
    @service = services(:printer_refill)
  end

  test "sync requires authentication" do
    get api_v1_services_sync_path, as: :json

    assert_response :redirect
  end

  test "sync returns all active services as JSON" do
    sign_in_as(users(:admin))

    get api_v1_services_sync_path, as: :json

    assert_response :success
    body = response.parsed_body
    assert body.key?("synced_at")
    assert body.key?("services")
    assert body["services"].is_a?(Array)

    service_data = body["services"].find { |s| s["id"] == @service.id }
    assert_not_nil service_data
    assert_equal @service.code, service_data["code"]
    assert_equal @service.name, service_data["name"]
    assert_equal @service.price.to_s, service_data["price"]
    assert service_data.key?("tax_code")
    assert service_data.key?("tax_rate")
    assert service_data.key?("updated_at")
  end

  test "sync works for common users" do
    sign_in_as(users(:one))

    get api_v1_services_sync_path, as: :json

    assert_response :success
  end

  test "sync with since param returns only updated services" do
    sign_in_as(users(:admin))
    future = 1.year.from_now.iso8601

    get api_v1_services_sync_path, params: { since: future }, as: :json

    assert_response :success
    body = response.parsed_body
    assert_empty body["services"]
  end

  test "sync with invalid since param returns all services" do
    sign_in_as(users(:admin))

    get api_v1_services_sync_path, params: { since: "not-a-date" }, as: :json

    assert_response :success
    body = response.parsed_body
    assert body["services"].any?
  end
end
