# frozen_string_literal: true

require "test_helper"
require "aws-sdk-s3"

class MinioBackupJobTest < ActiveJob::TestCase
  test "perform creates archive, uploads to drive, and cleans up temp file" do
    upload_called = false
    prune_called = false

    fake_result = Data.define(:id, :name).new(id: "drive_456", name: "minio_backup_test.tar.gz")

    mock_client = build_mock_s3_client

    upload_stub = ->(_path, **_opts) { upload_called = true; fake_result }
    prune_stub = ->(**_opts) { prune_called = true; 0 }

    GoogleDriveService.stub(:upload, upload_stub) do
      GoogleDriveService.stub(:prune, prune_stub) do
        Aws::S3::Client.stub(:new, mock_client) do
          MinioBackupJob.perform_now
        end
      end
    end

    assert upload_called, "Expected GoogleDriveService.upload to be called"
    assert prune_called, "Expected GoogleDriveService.prune to be called"

    temp_files = Dir.glob(Rails.root.join("tmp", "minio_backup_*.tar.gz"))
    assert_empty temp_files, "Temp backup file should be cleaned up"
  end

  test "cleans up temp file even when upload fails" do
    mock_client = build_mock_s3_client

    upload_stub = ->(_path, **_opts) { raise "Upload failed" }

    GoogleDriveService.stub(:upload, upload_stub) do
      Aws::S3::Client.stub(:new, mock_client) do
        assert_raises(RuntimeError) do
          MinioBackupJob.perform_now
        end
      end
    end

    temp_files = Dir.glob(Rails.root.join("tmp", "minio_backup_*.tar.gz"))
    assert_empty temp_files, "Temp backup file should be cleaned up even on failure"
  end

  private

    def build_mock_s3_client
      fake_object = Aws::S3::Types::Object.new(key: "uploads/test.jpg", size: 100)
      fake_list_page = Aws::S3::Types::ListObjectsV2Output.new(
        contents: [ fake_object ],
        is_truncated: false
      )

      mock = Object.new
      mock.define_singleton_method(:list_objects_v2) do |**_opts|
        [ fake_list_page ]
      end
      mock.define_singleton_method(:get_object) do |**_opts|
        body = StringIO.new("fake image data")
        Data.define(:body).new(body: body)
      end
      mock
    end
end
