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
      assert_equal "Admin Settings", inertia_props["title"]
      assert_equal "cards", inertia_props["view"]
    end

    test "show displays store details card" do
      get admin_settings_path
      assert_response :success
      assert_includes inertia_props["cards"].map { |card| card["title"] }, "Store"
    end

    test "show displays all admin section cards" do
      get admin_settings_path
      assert_response :success
      titles = inertia_props["cards"].map { |card| card["title"] }
      %w[Users Suppliers Backups Shopify].each { |title| assert_includes titles, title }
      [ "Tax codes", "Receipt templates", "Audit log", "Data export", "Stock imports" ].each { |title| assert_includes titles, title }
    end

    test "non-admin cannot access settings" do
      sign_in_as(users(:one))
      get admin_settings_path
      assert_redirected_to root_path
    end
  end
end
