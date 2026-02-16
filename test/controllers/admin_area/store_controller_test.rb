# frozen_string_literal: true

require "test_helper"

module AdminArea
  class StoreControllerTest < ActionDispatch::IntegrationTest
    setup do
      sign_in_as(users(:admin))
    end

    # ── Show ──────────────────────────────────────────────────────────

    test "show renders store details page" do
      get admin_store_path
      assert_response :success
      assert_includes response.body, "Store details"
    end

    test "show displays accent colour swatches" do
      get admin_store_path
      assert_response :success
      Store::ACCENT_COLOR_NAMES.each do |color|
        assert_includes response.body, "data-color=\"#{color}\""
      end
    end

    test "show displays logo upload field" do
      get admin_store_path
      assert_response :success
      assert_includes response.body, "Store logo"
    end

    # ── Update ────────────────────────────────────────────────────────

    test "update changes the accent colour" do
      patch admin_store_path, params: { store: { accent_color: "blue" } }
      assert_redirected_to admin_store_path
      assert_equal "blue", Store.current.reload.accent_color
    end

    test "update changes store name" do
      patch admin_store_path, params: { store: { name: "New Store Name" } }
      assert_redirected_to admin_store_path
      assert_equal "New Store Name", Store.current.reload.name
    end

    test "update rejects invalid accent colour" do
      patch admin_store_path, params: { store: { accent_color: "neon_pink" } }
      assert_response :unprocessable_entity
    end

    test "update can upload a store logo" do
      logo = fixture_file_upload("test_logo_square.png", "image/png")
      patch admin_store_path, params: { store: { logo: logo } }
      assert_redirected_to admin_store_path
      assert Store.current.reload.logo.attached?
    end

    # ── Authorization ─────────────────────────────────────────────────

    test "non-admin cannot access store settings" do
      sign_in_as(users(:one))
      get admin_store_path
      assert_redirected_to root_path
    end

    test "non-admin cannot update store settings" do
      sign_in_as(users(:one))
      patch admin_store_path, params: { store: { name: "Hacked" } }
      assert_redirected_to root_path
    end
  end
end
