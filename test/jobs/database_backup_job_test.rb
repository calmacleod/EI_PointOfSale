# frozen_string_literal: true

require "test_helper"

class DatabaseBackupJobTest < ActiveJob::TestCase
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

    GoogleDriveService.stub(:upload, upload_stub) do
      GoogleDriveService.stub(:prune, prune_stub) do
        DatabaseBackupJob.new.stub(:system, system_stub) do |job|
          job.perform_now
        end
      end
    end

    assert upload_called, "Expected GoogleDriveService.upload to be called"
    assert prune_called, "Expected GoogleDriveService.prune to be called"

    temp_dump_files = Dir.glob(Rails.root.join("tmp", "db_backup_*.dump"))
    temp_gz_files = Dir.glob(Rails.root.join("tmp", "db_backup_*.dump.gz"))
    assert_empty temp_dump_files, "Temp raw dump should be cleaned up"
    assert_empty temp_gz_files, "Temp compressed dump should be cleaned up"
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

    GoogleDriveService.stub(:upload, upload_stub) do
      DatabaseBackupJob.new.stub(:system, system_stub) do |job|
        assert_raises(RuntimeError) do
          job.perform_now
        end
      end
    end

    temp_dump_files = Dir.glob(Rails.root.join("tmp", "db_backup_*.dump"))
    temp_gz_files = Dir.glob(Rails.root.join("tmp", "db_backup_*.dump.gz"))
    assert_empty temp_dump_files, "Temp raw dump should be cleaned up even on failure"
    assert_empty temp_gz_files, "Temp compressed dump should be cleaned up even on failure"
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
