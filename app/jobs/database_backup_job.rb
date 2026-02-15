# frozen_string_literal: true

# Nightly job that creates a compressed PostgreSQL dump of the primary database
# and uploads it to Google Drive. Old backups are pruned to keep the last 7.
#
# Scheduled via config/recurring.yml.
class DatabaseBackupJob < ApplicationJob
  queue_as :low

  BACKUP_PREFIX = "db_backup_"
  RETENTION_COUNT = 7

  def perform
    timestamp = Time.current.strftime("%Y%m%d_%H%M%S")
    filename = "#{BACKUP_PREFIX}#{timestamp}.dump.gz"
    raw_dump = Rails.root.join("tmp", "#{BACKUP_PREFIX}#{timestamp}.dump").to_s
    dump_path = Rails.root.join("tmp", filename).to_s

    begin
      create_dump(raw_dump)
      compress(raw_dump, dump_path)
      upload_to_drive(dump_path)
      prune_old_backups
      Rails.logger.info { "[DatabaseBackupJob] Backup completed: #{filename}" }
    ensure
      FileUtils.rm_f(raw_dump)
      FileUtils.rm_f(dump_path)
    end
  end

  private

    def create_dump(dump_path)
      db_config = ActiveRecord::Base.connection_db_config.configuration_hash

      env = {}
      env["PGPASSWORD"] = db_config[:password].to_s if db_config[:password].present?

      cmd = [ "pg_dump" ]
      cmd += [ "-h", db_config[:host].to_s ] if db_config[:host].present?
      cmd += [ "-p", db_config[:port].to_s ] if db_config[:port].present?
      cmd += [ "-U", db_config[:username].to_s ] if db_config[:username].present?
      cmd += [ "--no-owner", "--no-acl", "-Fc", "-f", dump_path, db_config[:database].to_s ]

      success = system(env, *cmd)
      raise "pg_dump failed" unless success

      Rails.logger.info { "[DatabaseBackupJob] Dump created: #{dump_path} (#{File.size(dump_path)} bytes)" }
    end

    def compress(source, destination)
      File.open(destination, "wb") do |out|
        Zlib::GzipWriter.wrap(out) do |gz|
          File.open(source, "rb") do |input|
            while (chunk = input.read(16_384))
              gz.write(chunk)
            end
          end
        end
      end
    end

    def upload_to_drive(dump_path)
      result = GoogleDriveService.upload(dump_path, content_type: "application/gzip")
      Rails.logger.info { "[DatabaseBackupJob] Uploaded to Drive: #{result.name} (id: #{result.id})" }
    end

    def prune_old_backups
      deleted = GoogleDriveService.prune(prefix: BACKUP_PREFIX, keep: RETENTION_COUNT)
      Rails.logger.info { "[DatabaseBackupJob] Pruned #{deleted} old backup(s)" } if deleted > 0
    end
end
