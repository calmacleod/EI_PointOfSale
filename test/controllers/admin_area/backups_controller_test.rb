# frozen_string_literal: true

require "test_helper"

module AdminArea
  class BackupsControllerTest < ActionDispatch::IntegrationTest
    setup do
      sign_in_as(users(:admin))
    end

    # ── show ──

    test "show renders when credentials are not configured" do
      GoogleDriveService.stub(:check_credentials, { configured: false, connected: false, error: "OAuth client credentials not set" }) do
        get admin_backups_path
      end

      assert_response :success
      assert_includes response.body, "Backups"
      assert_includes response.body, "Not configured"
    end

    test "show renders when configured but not connected" do
      creds = { configured: true, connected: false, error: "Not connected" }

      GoogleDriveService.stub(:check_credentials, creds) do
        get admin_backups_path
      end

      assert_response :success
      assert_includes response.body, "Not connected"
      assert_includes response.body, "Connect Google Drive"
    end

    test "show renders when connected with backup files" do
      fake_file = build_fake_drive_file(id: "f1", name: "db_backup_20260215.dump.gz", size: 1024)
      creds = { configured: true, connected: true, error: nil, email: "user@gmail.com", display_name: "Test User" }

      GoogleDriveService.stub(:check_credentials, creds) do
        GoogleDriveService.stub(:list_files, ->(**opts) {
          opts[:prefix]&.start_with?("db_backup_") ? [ fake_file ] : []
        }) do
          get admin_backups_path
        end
      end

      assert_response :success
      assert_includes response.body, "Connected"
      assert_includes response.body, "user@gmail.com"
      assert_includes response.body, "db_backup_20260215.dump.gz"
      assert_includes response.body, "Disconnect"
    end

    test "show handles GoogleDriveService::Error gracefully" do
      GoogleDriveService.stub(:check_credentials, -> { raise GoogleDriveService::Error, "Something went wrong" }) do
        get admin_backups_path
      end

      assert_response :success
      assert_includes response.body, "Something went wrong"
    end

    # ── download ──

    test "download streams file from Google Drive" do
      fake_io = StringIO.new("backup file contents")

      GoogleDriveService.stub(:download, ->(_id) { fake_io }) do
        get download_admin_backups_path(file_id: "drive_file_123", file_name: "db_backup_test.dump.gz")
      end

      assert_response :success
      assert_equal "backup file contents", response.body
      assert_match(/attachment/, response.headers["Content-Disposition"])
      assert_match(/db_backup_test\.dump\.gz/, response.headers["Content-Disposition"])
    end

    test "download redirects with alert on API error" do
      GoogleDriveService.stub(:download, ->(_id) { raise Google::Apis::ClientError.new("Not found") }) do
        get download_admin_backups_path(file_id: "bad_id", file_name: "missing.gz")
      end

      assert_redirected_to admin_backups_path
      assert_match(/Download failed/, flash[:alert])
    end

    # ── authorize ──

    test "authorize redirects to Google consent URL" do
      GoogleDriveService.stub(:authorization_url, ->(**_opts) { "https://accounts.google.com/o/oauth2/auth?test=1" }) do
        get authorize_admin_backups_path
      end

      assert_response :redirect
      assert_match %r{accounts\.google\.com}, response.location
    end

    # ── oauth_callback ──

    test "oauth_callback exchanges code and redirects with notice" do
      exchange_called = false

      GoogleDriveService.stub(:exchange_code, ->(**_opts) { exchange_called = true; true }) do
        get oauth_callback_admin_backups_path(code: "test_auth_code")
      end

      assert exchange_called
      assert_redirected_to admin_backups_path
      assert_equal "Google Drive connected successfully.", flash[:notice]
    end

    test "oauth_callback redirects with alert when code is blank" do
      get oauth_callback_admin_backups_path

      assert_redirected_to admin_backups_path
      assert_match(/cancelled or failed/, flash[:alert])
    end

    test "oauth_callback redirects with alert on exchange failure" do
      GoogleDriveService.stub(:exchange_code, ->(**_opts) { raise "Token exchange failed" }) do
        get oauth_callback_admin_backups_path(code: "bad_code")
      end

      assert_redirected_to admin_backups_path
      assert_match(/Authorization failed/, flash[:alert])
    end

    # ── disconnect ──

    test "disconnect removes token and redirects with notice" do
      disconnect_called = false

      GoogleDriveService.stub(:disconnect!, -> { disconnect_called = true }) do
        delete disconnect_admin_backups_path
      end

      assert disconnect_called
      assert_redirected_to admin_backups_path
      assert_equal "Google Drive disconnected.", flash[:notice]
    end

    # ── authorization ──

    test "non-admin cannot access backups" do
      sign_in_as(users(:one))
      get admin_backups_path
      assert_redirected_to root_path
    end

    test "non-admin cannot authorize" do
      sign_in_as(users(:one))
      get authorize_admin_backups_path
      assert_redirected_to root_path
    end

    test "non-admin cannot disconnect" do
      sign_in_as(users(:one))
      delete disconnect_admin_backups_path
      assert_redirected_to root_path
    end

    private

      def build_fake_drive_file(id:, name:, size: nil)
        Google::Apis::DriveV3::File.new(
          id: id,
          name: name,
          size: size,
          created_time: 1.hour.ago
        )
      end
  end
end
