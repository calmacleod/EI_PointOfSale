# frozen_string_literal: true

require "aws-sdk-s3"
require "rubygems/package"

# Nightly job that archives all objects in the MinIO bucket into a compressed
# tarball and uploads it to Google Drive. Old backups are pruned to keep the last 7.
#
# Scheduled via config/recurring.yml.
class MinioBackupJob < ApplicationJob
  queue_as :low

  BACKUP_PREFIX = "minio_backup_"
  RETENTION_COUNT = 7

  def perform
    timestamp = Time.current.strftime("%Y%m%d_%H%M%S")
    filename = "#{BACKUP_PREFIX}#{timestamp}.tar.gz"
    archive_path = Rails.root.join("tmp", filename).to_s

    begin
      create_archive(archive_path)
      upload_to_drive(archive_path)
      prune_old_backups
      Rails.logger.info { "[MinioBackupJob] Backup completed: #{filename}" }
      notify_admins("Storage backup complete", "Nightly MinIO backup uploaded to Google Drive.")
    ensure
      FileUtils.rm_f(archive_path)
    end
  end

  private

    def create_archive(archive_path)
      config = minio_config
      client = build_s3_client(config)
      bucket = config["bucket"]

      object_count = 0

      File.open(archive_path, "wb") do |file|
        Zlib::GzipWriter.wrap(file) do |gz|
          Gem::Package::TarWriter.new(gz) do |tar|
            client.list_objects_v2(bucket: bucket).each do |response|
              response.contents.each do |object|
                obj_data = client.get_object(bucket: bucket, key: object.key)
                body = obj_data.body.read

                tar.add_file_simple(object.key, 0o644, body.bytesize) do |entry|
                  entry.write(body)
                end

                object_count += 1
              end
            end
          end
        end
      end

      Rails.logger.info do
        "[MinioBackupJob] Archive created: #{archive_path} " \
          "(#{object_count} objects, #{File.size(archive_path)} bytes)"
      end
    end

    def upload_to_drive(archive_path)
      result = GoogleDriveService.upload(archive_path, content_type: "application/gzip")
      Rails.logger.info { "[MinioBackupJob] Uploaded to Drive: #{result.name} (id: #{result.id})" }
    end

    def notify_admins(title, body)
      User.where(type: "Admin").find_each do |admin|
        NotifyService.call(user: admin, title:, body:, category: "backup", persistent: false)
      end
    end

    def prune_old_backups
      deleted = GoogleDriveService.prune(prefix: BACKUP_PREFIX, keep: RETENTION_COUNT)
      Rails.logger.info { "[MinioBackupJob] Pruned #{deleted} old backup(s)" } if deleted > 0
    end

    def minio_config
      storage_config = Rails.root.join("config/storage.yml")
      configs = ActiveSupport::ConfigurationFile.parse(storage_config)
      config = configs["minio"]

      raise "No 'minio' service defined in config/storage.yml" unless config

      config
    end

    def build_s3_client(config)
      Aws::S3::Client.new(
        access_key_id: config["access_key_id"],
        secret_access_key: config["secret_access_key"],
        endpoint: config["endpoint"],
        region: config["region"],
        force_path_style: config["force_path_style"]
      )
    end
end
