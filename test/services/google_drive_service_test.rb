# frozen_string_literal: true

require "test_helper"

class GoogleDriveServiceTest < ActiveSupport::TestCase
  include ActiveJob::TestHelper

  setup do
    @original_client_id = ENV["GOOGLE_CLIENT_ID"]
    @original_client_secret = ENV["GOOGLE_CLIENT_SECRET"]
    @original_folder = ENV["GOOGLE_DRIVE_BACKUP_FOLDER_ID"]
    GoogleDriveService.send(:reset!)
  end

  teardown do
    ENV["GOOGLE_CLIENT_ID"] = @original_client_id
    ENV["GOOGLE_CLIENT_SECRET"] = @original_client_secret
    ENV["GOOGLE_DRIVE_BACKUP_FOLDER_ID"] = @original_folder
    GoogleDriveService.send(:reset!)
  end

  # ── validate_config! ──

  test "upload raises error when OAuth client credentials are missing" do
    ENV.delete("GOOGLE_CLIENT_ID")
    ENV.delete("GOOGLE_CLIENT_SECRET")
    ENV["GOOGLE_DRIVE_BACKUP_FOLDER_ID"] = "some_folder"

    error = assert_raises(GoogleDriveService::Error) do
      GoogleDriveService.upload("/tmp/test.txt")
    end

    assert_match(/GOOGLE_CLIENT_ID/, error.message)
  end

  test "upload raises error when GOOGLE_DRIVE_BACKUP_FOLDER_ID is missing" do
    ENV["GOOGLE_CLIENT_ID"] = "test_id"
    ENV["GOOGLE_CLIENT_SECRET"] = "test_secret"
    ENV.delete("GOOGLE_DRIVE_BACKUP_FOLDER_ID")

    error = assert_raises(GoogleDriveService::Error) do
      GoogleDriveService.upload("/tmp/test.txt")
    end

    assert_match(/GOOGLE_DRIVE_BACKUP_FOLDER_ID/, error.message)
  end

  test "upload raises error when OAuth token is not stored" do
    ENV["GOOGLE_CLIENT_ID"] = "test_id"
    ENV["GOOGLE_CLIENT_SECRET"] = "test_secret"
    ENV["GOOGLE_DRIVE_BACKUP_FOLDER_ID"] = "some_folder"

    GoogleDriveService.stub(:token_stored?, false) do
      error = assert_raises(GoogleDriveService::Error) do
        GoogleDriveService.upload("/tmp/test.txt")
      end

      assert_match(/not connected/i, error.message)
    end
  end

  # ── upload ──

  test "upload sends file to Google Drive with correct metadata" do
    configure_oauth!

    tmp_file = Tempfile.new([ "backup", ".sql.gz" ])
    tmp_file.write("test data")
    tmp_file.close

    uploaded_metadata = nil
    uploaded_kwargs = nil

    uploaded_file = Google::Apis::DriveV3::File.new(
      id: "drive_file_id",
      name: File.basename(tmp_file.path),
      size: 9,
      created_time: Time.current
    )

    fake_service = build_fake_drive_service
    fake_service.define_singleton_method(:create_file) do |metadata, **kwargs|
      uploaded_metadata = metadata
      uploaded_kwargs = kwargs
      uploaded_file
    end

    stub_drive_service(fake_service) do
      result = GoogleDriveService.upload(tmp_file.path, content_type: "application/gzip")

      assert_equal "drive_file_id", result.id
      assert_equal [ "test_folder_123" ], uploaded_metadata.parents
      assert_equal tmp_file.path, uploaded_kwargs[:upload_source]
      assert_equal "application/gzip", uploaded_kwargs[:content_type]
    end
  ensure
    tmp_file&.unlink
  end

  # ── list_files ──

  test "list_files returns files from Drive folder" do
    configure_oauth!

    expected_files = [
      Google::Apis::DriveV3::File.new(id: "f1", name: "db_backup_1.dump.gz", created_time: 1.day.ago),
      Google::Apis::DriveV3::File.new(id: "f2", name: "db_backup_2.dump.gz", created_time: 2.days.ago)
    ]

    fake_service = build_fake_drive_service
    fake_service.define_singleton_method(:list_files) do |**_kwargs|
      Google::Apis::DriveV3::FileList.new(files: expected_files)
    end

    stub_drive_service(fake_service) do
      files = GoogleDriveService.list_files(prefix: "db_backup_")

      assert_equal 2, files.size
      assert_equal "f1", files.first.id
    end
  end

  # ── check_credentials ──

  test "check_credentials returns not configured when client credentials missing" do
    ENV.delete("GOOGLE_CLIENT_ID")
    ENV.delete("GOOGLE_CLIENT_SECRET")

    result = GoogleDriveService.check_credentials

    assert_equal false, result[:configured]
    assert_equal false, result[:connected]
    assert_match(/OAuth client credentials/, result[:error])
  end

  test "check_credentials returns not configured when folder ID missing" do
    ENV["GOOGLE_CLIENT_ID"] = "test_id"
    ENV["GOOGLE_CLIENT_SECRET"] = "test_secret"
    ENV.delete("GOOGLE_DRIVE_BACKUP_FOLDER_ID")

    result = GoogleDriveService.check_credentials

    assert_equal false, result[:configured]
    assert_equal false, result[:connected]
    assert_match(/GOOGLE_DRIVE_BACKUP_FOLDER_ID/, result[:error])
  end

  test "check_credentials returns not connected when no token stored" do
    ENV["GOOGLE_CLIENT_ID"] = "test_id"
    ENV["GOOGLE_CLIENT_SECRET"] = "test_secret"
    ENV["GOOGLE_DRIVE_BACKUP_FOLDER_ID"] = "some_folder"

    GoogleDriveService.stub(:token_stored?, false) do
      result = GoogleDriveService.check_credentials

      assert_equal true, result[:configured]
      assert_equal false, result[:connected]
      assert_match(/not connected/i, result[:error])
    end
  end

  # ── prune ──

  test "prune deletes files beyond retention count" do
    configure_oauth!

    old_files = 3.times.map do |i|
      Google::Apis::DriveV3::File.new(
        id: "file_#{i}",
        name: "db_backup_#{i}.sql.gz",
        created_time: (i + 1).days.ago
      )
    end

    deleted_ids = []

    fake_service = build_fake_drive_service
    fake_service.define_singleton_method(:list_files) do |**_kwargs|
      Google::Apis::DriveV3::FileList.new(files: old_files)
    end
    fake_service.define_singleton_method(:delete_file) do |id, **_opts|
      deleted_ids << id
    end

    stub_drive_service(fake_service) do
      deleted_count = GoogleDriveService.prune(prefix: "db_backup_", keep: 1)

      assert_equal 2, deleted_count
      assert_equal [ "file_1", "file_2" ], deleted_ids
    end
  end

  # ── exchange_code / trigger_backup_if_stale! ──

  test "exchange_code enqueues DatabaseBackupJob when no backups exist on Drive" do
    configure_oauth!

    assert_enqueued_with(job: DatabaseBackupJob) do
      stub_exchange_code(backup_files: []) do
        GoogleDriveService.exchange_code(code: "auth_code", redirect_uri: "https://example.com/callback")
      end
    end
  end

  test "exchange_code enqueues DatabaseBackupJob when most recent backup is stale" do
    configure_oauth!

    stale_file = Google::Apis::DriveV3::File.new(
      id: "f1",
      name: "db_backup_old.dump.gz",
      created_time: 30.hours.ago
    )

    assert_enqueued_with(job: DatabaseBackupJob) do
      stub_exchange_code(backup_files: [ stale_file ]) do
        GoogleDriveService.exchange_code(code: "auth_code", redirect_uri: "https://example.com/callback")
      end
    end
  end

  test "exchange_code does not enqueue DatabaseBackupJob when a recent backup exists" do
    configure_oauth!

    fresh_file = Google::Apis::DriveV3::File.new(
      id: "f1",
      name: "db_backup_recent.dump.gz",
      created_time: 3.hours.ago
    )

    assert_no_enqueued_jobs(only: DatabaseBackupJob) do
      stub_exchange_code(backup_files: [ fresh_file ]) do
        GoogleDriveService.exchange_code(code: "auth_code", redirect_uri: "https://example.com/callback")
      end
    end
  end

  test "exchange_code still returns true when backup staleness check fails" do
    configure_oauth!

    fake_client = build_fake_oauth_client
    GoogleDriveService.stub(:build_oauth_client, fake_client) do
      GoogleDriveService.stub(:store_token, nil) do
        GoogleDriveService.stub(:list_files, ->(*) { raise "Drive error" }) do
          result = GoogleDriveService.exchange_code(code: "auth_code", redirect_uri: "https://example.com/callback")
          assert result
        end
      end
    end
  end

  # ── disconnect! ──

  test "disconnect! removes the token file" do
    token_path = GoogleDriveService::TOKEN_PATH
    token_path.dirname.mkpath
    token_path.write('{"refresh_token":"test"}')

    assert token_path.exist?
    GoogleDriveService.disconnect!
    assert_not token_path.exist?
  ensure
    FileUtils.rm_f(token_path)
  end

  private

    def configure_oauth!
      ENV["GOOGLE_CLIENT_ID"] = "test_id"
      ENV["GOOGLE_CLIENT_SECRET"] = "test_secret"
      ENV["GOOGLE_DRIVE_BACKUP_FOLDER_ID"] = "test_folder_123"
    end

    def build_fake_drive_service
      fake = Object.new
      fake.define_singleton_method(:authorization=) { |_| }
      fake
    end

    def build_fake_oauth_client
      fake = Object.new
      fake.define_singleton_method(:code=) { |_| }
      fake.define_singleton_method(:fetch_access_token!) { }
      fake.define_singleton_method(:refresh_token) { "fake_refresh_token" }
      fake
    end

    # Stubs exchange_code dependencies: OAuth client, token storage, and Drive file listing.
    def stub_exchange_code(backup_files:, &block)
      fake_client = build_fake_oauth_client
      file_list = Google::Apis::DriveV3::FileList.new(files: backup_files)

      fake_drive = build_fake_drive_service
      fake_drive.define_singleton_method(:list_files) { |**_| file_list }

      GoogleDriveService.stub(:build_oauth_client, fake_client) do
        GoogleDriveService.stub(:store_token, nil) do
          stub_drive_service(fake_drive, &block)
        end
      end
    end

    # Stubs the private drive_service and token_stored? so we bypass real auth.
    def stub_drive_service(fake_service, &block)
      GoogleDriveService.stub(:token_stored?, true) do
        Google::Apis::DriveV3::DriveService.stub(:new, fake_service) do
          # Stub load_credentials to return a simple object
          GoogleDriveService.stub(:load_credentials, "mock_creds", &block)
        end
      end
    end
end
