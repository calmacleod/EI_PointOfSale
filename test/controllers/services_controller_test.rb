# frozen_string_literal: true

require "test_helper"

class ServicesControllerTest < ActionDispatch::IntegrationTest
  setup do
    sign_in_as(users(:admin))
    @service = services(:printer_refill)
  end

  test "index lists services" do
    get services_path

    assert_response :success
    assert_includes response.body, @service.name
  end

  test "show displays service" do
    get service_path(@service)

    assert_response :success
    assert_includes response.body, @service.name
  end

  test "show returns JSON preview data" do
    get service_path(@service, format: :json)

    assert_response :success
    body = response.parsed_body
    assert_equal @service.id, body["id"]
    assert_equal @service.code, body["code"]
    assert_equal @service.name, body["name"]
    assert_equal @service.price.to_s, body["price"]
  end

  test "new renders form" do
    get new_service_path

    assert_response :success
    assert_includes response.body, "New service"
  end

  test "create adds service and records creator" do
    assert_difference("Service.count", 1) do
      post services_path, params: {
        service: {
          name: "Console Cleaning",
          code: "SVC-CLEAN",
          description: "Basic console cleaning",
          price: 24.99,
          tax_code_id: tax_codes(:one).id
        }
      }
    end

    assert_redirected_to services_path
    service = Service.find_by!(code: "SVC-CLEAN")
    assert_equal users(:admin), service.added_by
    assert_equal 24.99, service.price.to_f
  end

  test "create with invalid params renders new" do
    assert_no_difference("Service.count") do
      post services_path, params: { service: { name: "", price: "" } }
    end

    assert_response :unprocessable_entity
  end

  test "edit renders form" do
    get edit_service_path(@service)

    assert_response :success
    assert_includes response.body, @service.name
  end

  test "update modifies service" do
    patch service_path(@service), params: { service: { name: "Updated Refill", price: 14.99 } }

    assert_redirected_to services_path
    assert_equal "Updated Refill", @service.reload.name
    assert_equal 14.99, @service.price.to_f
  end

  test "destroy discards service" do
    delete service_path(@service)

    assert_redirected_to services_path
    assert @service.reload.discarded?
  end

  test "preview renders partial for authorized readers" do
    get preview_service_path(@service)

    assert_response :success
    assert_includes response.body, @service.name
  end

  test "common user can view services" do
    sign_in_as(users(:one))

    get service_path(@service)

    assert_response :success
  end

  test "common user cannot create services" do
    sign_in_as(users(:one))

    assert_no_difference("Service.count") do
      post services_path, params: { service: { name: "Unauthorized", price: 1.00 } }
    end

    assert_redirected_to root_path
  end
end
