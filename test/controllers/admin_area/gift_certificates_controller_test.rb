# frozen_string_literal: true

require "test_helper"

module AdminArea
  class GiftCertificatesControllerTest < ActionDispatch::IntegrationTest
    setup do
      @admin = users(:admin)
      sign_in_as(@admin)
    end

    test "GET /admin/gift_certificates lists all gift certificates" do
      get admin_gift_certificates_path
      assert_response :success
    end

    test "GET /admin/gift_certificates with status filter" do
      get admin_gift_certificates_path, params: { status: "active" }
      assert_response :success
    end

    test "GET /admin/gift_certificates/:id shows gift certificate details" do
      gc = gift_certificates(:active_gc)
      get admin_gift_certificate_path(gc)
      assert_response :success
    end

    test "GET /admin/gift_certificates/:id includes printable certificate" do
      gc = gift_certificates(:active_gc)
      get admin_gift_certificate_path(gc)
      assert_response :success

      assert_equal "gift_certificate_show", inertia_props["view"]
      assert_equal gc.code, inertia_props.dig("certificate", "code")
      assert_equal "$75.00", inertia_props.dig("certificate", "remaining_balance")
    end

    test "GET /admin/gift_certificates/:id shows redemption history" do
      gc = gift_certificates(:active_gc)
      get admin_gift_certificate_path(gc)
      assert_response :success
      assert_equal "gift_certificate_show", inertia_props["view"]
      assert_kind_of Array, inertia_props["redemptions"]
    end

    test "common user cannot access admin gift certificates index" do
      sign_in_as(users(:one))
      get admin_gift_certificates_path
      assert_response :redirect
    end

    test "common user cannot access admin gift certificate show" do
      sign_in_as(users(:one))
      get admin_gift_certificate_path(gift_certificates(:active_gc))
      assert_response :redirect
    end

    test "requires authentication" do
      delete session_path
      get admin_gift_certificates_path
      assert_redirected_to new_session_path
    end
  end
end
