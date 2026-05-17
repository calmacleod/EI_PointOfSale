# frozen_string_literal: true

require "test_helper"

module AdminArea
  class TaxCodesControllerTest < ActionDispatch::IntegrationTest
    setup do
      sign_in_as(users(:admin))
      @tax_code = tax_codes(:one)
    end

    test "index lists tax codes" do
      get admin_tax_codes_path

      assert_response :success
      assert_includes response.body, @tax_code.code
      assert_includes response.body, @tax_code.name
    end

    test "show displays tax code" do
      get admin_tax_code_path(@tax_code)

      assert_response :success
      assert_includes response.body, @tax_code.code
      assert_includes response.body, @tax_code.name
    end

    test "new renders form" do
      get new_admin_tax_code_path

      assert_response :success
      assert_includes response.body, "New tax code"
    end

    test "create adds tax code and converts percentage input" do
      assert_difference("TaxCode.count", 1) do
        post admin_tax_codes_path, params: {
          tax_code: {
            code: "GST",
            name: "Goods and Services Tax",
            rate: "5",
            province_code: "CA"
          }
        }
      end

      assert_redirected_to admin_tax_codes_path
      created = TaxCode.find_by!(code: "GST")
      assert_equal 0.05, created.rate.to_f
    end

    test "edit renders form" do
      get edit_admin_tax_code_path(@tax_code)

      assert_response :success
      assert_includes response.body, @tax_code.code
    end

    test "update modifies tax code and converts percentage input" do
      patch admin_tax_code_path(@tax_code), params: {
        tax_code: { name: "Updated HST", rate: "15", province_code: "ON" }
      }

      assert_redirected_to admin_tax_codes_path
      assert_equal "Updated HST", @tax_code.reload.name
      assert_equal 0.15, @tax_code.rate.to_f
    end

    test "destroy soft-deletes tax code" do
      delete admin_tax_code_path(@tax_code)

      assert_redirected_to admin_tax_codes_path
      assert @tax_code.reload.discarded?
    end

    test "non-admin cannot access tax codes" do
      sign_in_as(users(:one))

      get admin_tax_codes_path

      assert_redirected_to root_path
    end
  end
end
