# frozen_string_literal: true

require "test_helper"

module AdminArea
  class DataExportsControllerTest < ActionDispatch::IntegrationTest
    setup do
      sign_in_as(users(:admin))
    end

    test "show renders the data export page" do
      get admin_data_export_path

      assert_response :success
      assert_includes response.body, "Data export"
      assert_includes response.body, "Download Excel export"

      # Verify table list is shown
      DatabaseExportService::EXPORT_TABLES.each do |table|
        assert_includes response.body, table.titleize
      end
    end

    test "create downloads an xlsx file" do
      post admin_data_export_path

      assert_response :success
      assert_equal "application/vnd.openxmlformats-officedocument.spreadsheetml.sheet", response.content_type
      assert_match(/attachment/, response.headers["Content-Disposition"])
      assert_match(/ei_pos_export_\d{8}_\d{6}\.xlsx/, response.headers["Content-Disposition"])
      assert response.body.start_with?("PK"), "Expected xlsx (zip) file signature"
    end

    test "non-admin cannot access data export page" do
      sign_in_as(users(:one))
      get admin_data_export_path
      assert_redirected_to root_path
    end

    test "non-admin cannot download data export" do
      sign_in_as(users(:one))
      post admin_data_export_path
      assert_redirected_to root_path
    end
  end
end
