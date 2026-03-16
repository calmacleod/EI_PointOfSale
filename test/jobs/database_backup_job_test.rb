# frozen_string_literal: true

require "test_helper"

class DatabaseBackupJobTest < ActiveJob::TestCase
  setup do
    FileUtils.mkdir_p(Rails.root.join("tmp"))
  end

  test "perform creates dump, uploads to drive, and cleans up temp files" do
    upload_called = false
    prune_called = false

    fake_result = Data.define(:id, :name).new(id: "drive_123", name: "db_backup_test.dump.gz")

    upload_stub = ->(_path, **_opts) { upload_called = true; fake_result }
    prune_stub = ->(**_opts) { prune_called = true; 0 }

    # Stub system() call (pg_dump) to write a fake dump file and return true
    system_stub = ->(*args) {
      # Find the -f flag to get the output path
      f_index = args.index("-f")
      if f_index
        dump_path = args[f_index + 1]
        File.write(dump_path, "FAKE PG DUMP DATA")
      end
      true
    }

    travel_to Time.zone.parse("2025-01-01 02:00:00") do
      GoogleDriveService.stub(:upload, upload_stub) do
        GoogleDriveService.stub(:prune, prune_stub) do
          DatabaseBackupJob.new.stub(:system, system_stub) do |job|
            job.perform_now
          end
        end
      end
    end

    assert upload_called, "Expected GoogleDriveService.upload to be called"
    assert prune_called, "Expected GoogleDriveService.prune to be called"

    refute File.exist?(Rails.root.join("tmp", "db_backup_20250101_020000.dump").to_s), "Temp raw dump should be cleaned up"
    refute File.exist?(Rails.root.join("tmp", "db_backup_20250101_020000.dump.gz").to_s), "Temp compressed dump should be cleaned up"
  end

  test "cleans up temp files even when upload fails" do
    upload_stub = ->(_path, **_opts) { raise "Upload failed" }

    system_stub = ->(*args) {
      f_index = args.index("-f")
      if f_index
        dump_path = args[f_index + 1]
        File.write(dump_path, "FAKE PG DUMP DATA")
      end
      true
    }

    travel_to Time.zone.parse("2025-01-01 03:00:00") do
      GoogleDriveService.stub(:upload, upload_stub) do
        DatabaseBackupJob.new.stub(:system, system_stub) do |job|
          assert_raises(RuntimeError) do
            job.perform_now
          end
        end
      end
    end

    refute File.exist?(Rails.root.join("tmp", "db_backup_20250101_030000.dump").to_s), "Temp raw dump should be cleaned up even on failure"
    refute File.exist?(Rails.root.join("tmp", "db_backup_20250101_030000.dump.gz").to_s), "Temp compressed dump should be cleaned up even on failure"
  end

  test "raises when pg_dump fails" do
    system_stub = ->(*_args) { false }

    DatabaseBackupJob.new.stub(:system, system_stub) do |job|
      error = assert_raises(RuntimeError) do
        job.perform_now
      end
      assert_match(/pg_dump failed/, error.message)
    end
  end
end
