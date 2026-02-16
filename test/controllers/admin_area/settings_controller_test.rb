# frozen_string_literal: true

require "test_helper"

module AdminArea
  class SettingsControllerTest < ActionDispatch::IntegrationTest
    setup do
      sign_in_as(users(:admin))
    end

    test "show renders admin settings page" do
      get admin_settings_path
      assert_response :success
      assert_includes response.body, "Admin settings"
    end

    test "show displays store details card" do
      get admin_settings_path
      assert_response :success
      assert_includes response.body, "Store details"
    end

    test "show displays all admin section cards" do
      get admin_settings_path
      assert_response :success
      assert_includes response.body, "Users"
      assert_includes response.body, "Tax codes"
      assert_includes response.body, "Suppliers"
      assert_includes response.body, "Receipt Templates"
      assert_includes response.body, "Audit trail"
      assert_includes response.body, "Backups"
      assert_includes response.body, "Data export"
    end

    test "non-admin cannot access settings" do
      sign_in_as(users(:one))
      get admin_settings_path
      assert_redirected_to root_path
    end
  end
end
