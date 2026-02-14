# frozen_string_literal: true

require "test_helper"

module AdminArea
  class SuppliersControllerTest < ActionDispatch::IntegrationTest
    setup do
      sign_in_as(users(:admin))
    end

    test "index lists suppliers" do
      supplier = suppliers(:diamond_comics)

      get admin_suppliers_path

      assert_response :success
      assert_includes response.body, supplier.name
    end

    test "show displays supplier" do
      supplier = suppliers(:diamond_comics)

      get admin_supplier_path(supplier)

      assert_response :success
      assert_includes response.body, supplier.name
      assert_includes response.body, supplier.phone
    end

    test "new renders form" do
      get new_admin_supplier_path

      assert_response :success
      assert_includes response.body, "New supplier"
    end

    test "create adds supplier" do
      assert_difference("Supplier.count", 1) do
        post admin_suppliers_path, params: { supplier: { name: "New Supplier", phone: "555-0100" } }
      end

      assert_redirected_to admin_suppliers_path
      follow_redirect!
      assert_includes response.body, "New Supplier"
    end

    test "create with invalid params renders new" do
      assert_no_difference("Supplier.count") do
        post admin_suppliers_path, params: { supplier: { name: "" } }
      end

      assert_response :unprocessable_entity
    end

    test "edit renders form" do
      supplier = suppliers(:diamond_comics)

      get edit_admin_supplier_path(supplier)

      assert_response :success
      assert_includes response.body, supplier.name
    end

    test "update modifies supplier" do
      supplier = suppliers(:diamond_comics)

      patch admin_supplier_path(supplier), params: { supplier: { name: "Updated Name", phone: "555-9999" } }

      assert_redirected_to admin_suppliers_path
      assert_equal "Updated Name", supplier.reload.name
      assert_equal "555-9999", supplier.phone
    end

    test "destroy soft-deletes supplier" do
      supplier = suppliers(:diamond_comics)

      delete admin_supplier_path(supplier)

      assert_redirected_to admin_suppliers_path
      assert supplier.reload.discarded?
    end

    test "non-admin cannot access suppliers" do
      sign_in_as(users(:one))

      get admin_suppliers_path

      assert_redirected_to root_path
    end
  end
end
