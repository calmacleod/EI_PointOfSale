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

    test "show displays accent colour swatches" do
      get admin_settings_path
      assert_response :success
      Store::ACCENT_COLOR_NAMES.each do |color|
        assert_includes response.body, "data-color=\"#{color}\""
      end
    end

    test "update changes the accent colour" do
      patch admin_settings_path, params: { store: { accent_color: "blue" } }
      assert_redirected_to admin_settings_path
      assert_equal "blue", Store.current.reload.accent_color
    end

    test "update rejects invalid accent colour" do
      patch admin_settings_path, params: { store: { accent_color: "neon_pink" } }
      assert_response :unprocessable_entity
    end

    test "update can upload a store logo" do
      logo = fixture_file_upload("test_logo_square.png", "image/png")
      patch admin_settings_path, params: { store: { logo: logo } }
      assert_redirected_to admin_settings_path
      assert Store.current.reload.logo.attached?
    end

    test "show displays logo upload field" do
      get admin_settings_path
      assert_response :success
      assert_includes response.body, "Store logo"
    end

    test "non-admin cannot access settings" do
      sign_in_as(users(:one))
      get admin_settings_path
      assert_redirected_to root_path
    end
  end
end
