# frozen_string_literal: true

require "test_helper"

module AdminArea
  class ReceiptTemplatesControllerTest < ActionDispatch::IntegrationTest
    setup do
      sign_in_as(users(:admin))
    end

    # ── Index ──────────────────────────────────────────────────────────

    test "index lists receipt templates" do
      get admin_receipt_templates_path
      assert_response :success
      assert_includes response.body, receipt_templates(:standard).name
      assert_includes response.body, receipt_templates(:narrow).name
    end

    # ── Show ───────────────────────────────────────────────────────────

    test "show displays template with preview" do
      template = receipt_templates(:standard)
      get admin_receipt_template_path(template)
      assert_response :success
      assert_includes response.body, template.name
      assert_includes response.body, "Preview"
    end

    # ── New ────────────────────────────────────────────────────────────

    test "new renders form" do
      get new_admin_receipt_template_path
      assert_response :success
      assert_includes response.body, "New Receipt Template"
    end

    # ── Create ─────────────────────────────────────────────────────────

    test "create adds receipt template" do
      assert_difference("ReceiptTemplate.count", 1) do
        post admin_receipt_templates_path, params: {
          receipt_template: {
            name: "Custom 80mm",
            paper_width_mm: 80,
            show_store_name: true,
            show_store_address: false,
            footer_text: "Thanks!"
          }
        }
      end

      assert_redirected_to admin_receipt_templates_path
    end

    test "create with show_logo param" do
      assert_difference("ReceiptTemplate.count", 1) do
        post admin_receipt_templates_path, params: {
          receipt_template: {
            name: "Logo Test",
            paper_width_mm: 80,
            show_logo: true,
            show_store_name: true
          }
        }
      end

      template = ReceiptTemplate.order(:created_at).last
      assert template.show_logo?
    end

    test "create with trim_logo param" do
      assert_difference("ReceiptTemplate.count", 1) do
        post admin_receipt_templates_path, params: {
          receipt_template: {
            name: "Trim Test",
            paper_width_mm: 80,
            show_logo: true,
            trim_logo: true,
            show_store_name: true
          }
        }
      end

      template = ReceiptTemplate.order(:created_at).last
      assert template.trim_logo?
    end

    test "create with invalid params renders new" do
      assert_no_difference("ReceiptTemplate.count") do
        post admin_receipt_templates_path, params: {
          receipt_template: { name: "", paper_width_mm: 80 }
        }
      end

      assert_response :unprocessable_entity
    end

    # ── Edit ───────────────────────────────────────────────────────────

    test "edit renders form" do
      template = receipt_templates(:standard)
      get edit_admin_receipt_template_path(template)
      assert_response :success
      assert_includes response.body, template.name
    end

    # ── Update ─────────────────────────────────────────────────────────

    test "update modifies template" do
      template = receipt_templates(:narrow)
      patch admin_receipt_template_path(template), params: {
        receipt_template: { name: "Updated Narrow" }
      }

      assert_redirected_to admin_receipt_template_path(template)
      assert_equal "Updated Narrow", template.reload.name
    end

    test "update with invalid params renders edit" do
      template = receipt_templates(:standard)
      patch admin_receipt_template_path(template), params: {
        receipt_template: { name: "" }
      }

      assert_response :unprocessable_entity
    end

    # ── Destroy ────────────────────────────────────────────────────────

    test "destroy deletes template" do
      template = receipt_templates(:narrow)
      assert_difference("ReceiptTemplate.count", -1) do
        delete admin_receipt_template_path(template)
      end

      assert_redirected_to admin_receipt_templates_path
    end

    # ── Activate ───────────────────────────────────────────────────────

    test "activate makes template active" do
      standard = receipt_templates(:standard)
      narrow = receipt_templates(:narrow)

      patch activate_admin_receipt_template_path(narrow)

      assert_redirected_to admin_receipt_templates_path
      assert narrow.reload.active?
      assert_not standard.reload.active?
    end

    # ── Preview ────────────────────────────────────────────────────────

    test "preview returns partial" do
      template = receipt_templates(:standard)
      get preview_admin_receipt_template_path(template)
      assert_response :success
    end

    # ── Non-admin access ─────────────────────────────────────────────

    test "non-admin cannot access receipt templates" do
      sign_in_as(users(:one))
      get admin_receipt_templates_path
      assert_redirected_to root_path
    end

    test "non-admin cannot create receipt templates" do
      sign_in_as(users(:one))
      assert_no_difference("ReceiptTemplate.count") do
        post admin_receipt_templates_path, params: {
          receipt_template: { name: "Hacked", paper_width_mm: 80 }
        }
      end
      assert_redirected_to root_path
    end
  end
end
