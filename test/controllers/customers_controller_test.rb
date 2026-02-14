# frozen_string_literal: true

require "test_helper"

class CustomersControllerTest < ActionDispatch::IntegrationTest
  setup do
    sign_in_as(users(:admin))
  end

  test "index lists customers" do
    customer = customers(:acme_corp)

    get customers_path

    assert_response :success
    assert_includes response.body, customer.name
    assert_includes response.body, customer.member_number
  end

  test "show displays customer" do
    customer = customers(:acme_corp)

    get customer_path(customer)

    assert_response :success
    assert_includes response.body, customer.name
    assert_includes response.body, customer.phone
    assert_includes response.body, "123 Main St"
  end

  test "new renders form" do
    get new_customer_path

    assert_response :success
    assert_includes response.body, "New customer"
  end

  test "create adds customer" do
    assert_difference("Customer.count", 1) do
      post customers_path, params: {
        customer: {
          name: "New Customer",
          phone: "555-1234",
          email: "new@example.com",
          active: true
        }
      }
    end

    assert_redirected_to customers_path
    follow_redirect!
    assert_includes response.body, "New Customer"

    customer = Customer.find_by(name: "New Customer")
    assert_equal users(:admin).id, customer.added_by_id
  end

  test "create with invalid params renders new" do
    assert_no_difference("Customer.count") do
      post customers_path, params: { customer: { name: "" } }
    end

    assert_response :unprocessable_entity
  end

  test "edit renders form" do
    customer = customers(:acme_corp)

    get edit_customer_path(customer)

    assert_response :success
    assert_includes response.body, customer.name
  end

  test "update modifies customer" do
    customer = customers(:acme_corp)

    patch customer_path(customer), params: {
      customer: { name: "Updated Name", phone: "555-9999" }
    }

    assert_redirected_to customers_path
    assert_equal "Updated Name", customer.reload.name
    assert_equal "555-9999", customer.phone
  end

  test "destroy soft-deletes customer" do
    customer = customers(:acme_corp)

    delete customer_path(customer)

    assert_redirected_to customers_path
    assert customer.reload.discarded?
  end

  test "index filters by active" do
    get customers_path, params: { filter: "active" }

    assert_response :success
    assert_includes response.body, customers(:acme_corp).name
    assert_includes response.body, customers(:jane_doe).name
    assert_not_includes response.body, customers(:inactive_customer).name
  end

  test "index filters by inactive" do
    get customers_path, params: { filter: "inactive" }

    assert_response :success
    assert_includes response.body, customers(:inactive_customer).name
    assert_not_includes response.body, customers(:acme_corp).name
  end

  test "common user can read customers" do
    sign_in_as(users(:one))

    get customers_path
    assert_response :success

    get customer_path(customers(:acme_corp))
    assert_response :success
  end

  test "common user cannot create customer" do
    sign_in_as(users(:one))

    get new_customer_path
    assert_redirected_to root_path
  end
end
