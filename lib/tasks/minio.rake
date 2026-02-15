namespace :minio do
  desc "Create the MinIO bucket for the current environment if it does not exist"
  task setup: :environment do
    require "aws-sdk-s3"

    storage_config = Rails.root.join("config/storage.yml")
    configs = ActiveSupport::ConfigurationFile.parse(storage_config)
    config = configs["minio"]

    unless config
      puts "⚠  No 'minio' service defined in config/storage.yml — skipping bucket setup."
      next
    end

    client = Aws::S3::Client.new(
      access_key_id:     config["access_key_id"],
      secret_access_key:  config["secret_access_key"],
      endpoint:           config["endpoint"],
      region:             config["region"],
      force_path_style:   config["force_path_style"]
    )

    bucket = config["bucket"]

    begin
      client.head_bucket(bucket: bucket)
      puts "Bucket '#{bucket}' already exists."
    rescue Aws::S3::Errors::NotFound, Aws::S3::Errors::NoSuchBucket
      client.create_bucket(bucket: bucket)
      puts "Created bucket '#{bucket}'."
    end
  end
end
