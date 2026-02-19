namespace :garage do
  desc "Setup Garage cluster layout (required before creating buckets)"
  task setup_cluster: :environment do
    puts "Setting up Garage cluster layout..."

    container = "ei_pointofsale_garage"
    zone = "dc1"
    capacity = "10G"
    garage_bin = "/garage"

    # Check if container is running
    check_cmd = "docker ps -q -f name=#{container}"
    container_id = `#{check_cmd}`.strip

    if container_id.empty?
      puts "✗ Garage container '#{container}' is not running. Start it with: docker-compose up -d garage"
      exit 1
    end

    # Get node ID
    puts "Getting node ID..."
    node_id = `docker exec #{container} #{garage_bin} status 2>/dev/null | grep -E '^[a-f0-9]{16}' | head -1 | awk '{print $1}'`.strip

    if node_id.empty?
      puts "✗ Could not get node ID. Is Garage fully started?"
      exit 1
    end

    puts "Found node: #{node_id[0..7]}..."

    # Assign layout
    puts "Assigning cluster layout..."
    assign_result = system("docker exec #{container} #{garage_bin} layout assign -z #{zone} -c #{capacity} #{node_id[0..7]}")

    unless assign_result
      puts "✗ Failed to assign layout"
      exit 1
    end

    # Apply layout
    puts "Applying cluster layout..."
    apply_result = system("docker exec #{container} #{garage_bin} layout apply --version 1")

    unless apply_result
      puts "✗ Failed to apply layout"
      exit 1
    end

    puts "✓ Cluster layout configured successfully"
  end

  desc "Create Garage bucket and key for current environment"
  task setup: :environment do
    require "aws-sdk-s3"

    storage_config = Rails.root.join("config/storage.yml")
    configs = ActiveSupport::ConfigurationFile.parse(storage_config)
    config = configs["garage"]

    unless config
      puts "⚠  No 'garage' service defined in config/storage.yml — skipping setup."
      next
    end

    container = "ei_pointofsale_garage"
    bucket = config["bucket"]
    key_name = "ei-pointofsale-#{Rails.env}-key"
    garage_bin = "/garage"

    # Check if container is running
    check_cmd = "docker ps -q -f name=#{container}"
    container_id = `#{check_cmd}`.strip

    if container_id.empty?
      puts "✗ Garage container '#{container}' is not running. Start it with: docker-compose up -d garage"
      puts "Then run: bin/rails garage:setup_cluster"
      next
    end

    # Create bucket
    puts "Creating bucket '#{bucket}'..."
    bucket_result = system("docker exec #{container} #{garage_bin} bucket create #{bucket} 2>/dev/null")

    if bucket_result
      puts "✓ Created bucket '#{bucket}'"
    else
      puts "⚠  Bucket '#{bucket}' may already exist"
    end

    # Create key
    puts "Creating API key '#{key_name}'..."
    key_output = `docker exec #{container} #{garage_bin} key create #{key_name} 2>&1`

    if key_output.include?("Key ID:")
      puts "✓ Created API key '#{key_name}'"

      # Extract key ID and secret from output
      key_id = key_output.match(/Key ID:\s*(\S+)/)&.[](1)
      secret_key = key_output.match(/Secret key:\s*(\S+)/)&.[](1)

      if key_id && secret_key
        puts ""
        puts "Key ID: #{key_id}"
        puts "Secret Key: #{secret_key}"
        puts ""
        puts "Add these to your environment:"
        puts "  export GARAGE_ACCESS_KEY=#{key_id}"
        puts "  export GARAGE_SECRET_KEY=#{secret_key}"

        # Allow key to access bucket
        puts ""
        puts "Granting access..."
        allow_result = system("docker exec #{container} #{garage_bin} bucket allow --read --write --owner #{bucket} --key #{key_name}")

        if allow_result
          puts "✓ Granted full access to key '#{key_name}' on bucket '#{bucket}'"
        else
          puts "⚠  Failed to grant access (may already have access)"
        end
      end
    else
      puts "⚠  Key '#{key_name}' may already exist, checking access..."

      # Try to grant access anyway
      allow_result = system("docker exec #{container} #{garage_bin} bucket allow --read --write --owner #{bucket} --key #{key_name}")

      if allow_result
        puts "✓ Granted full access to key '#{key_name}' on bucket '#{bucket}'"
      end
    end

    puts ""
    puts "Setup complete! Use the credentials above in your environment."
  end

  desc "Create all Garage buckets and keys for development, production, and test environments"
  task setup_all: :environment do
    container = "ei_pointofsale_garage"
    garage_bin = "/garage"

    # Check if container is running
    check_cmd = "docker ps -q -f name=#{container}"
    container_id = `#{check_cmd}`.strip

    if container_id.empty?
      puts "✗ Garage container '#{container}' is not running. Start it with: docker-compose up -d garage"
      puts "Then run: bin/rails garage:setup_cluster"
      exit 1
    end

    %w[development production test].each do |env|
      bucket = "ei-pointofsale-#{env}"
      key_name = "ei-pointofsale-#{env}-key"

      puts ""
      puts "Setting up #{env} environment..."
      puts "-" * 40

      # Create bucket
      puts "Creating bucket '#{bucket}'..."
      bucket_result = system("docker exec #{container} #{garage_bin} bucket create #{bucket} 2>/dev/null")
      puts bucket_result ? "✓ Created bucket" : "⚠  Bucket may already exist"

      # Create key
      puts "Creating API key '#{key_name}'..."
      key_output = `docker exec #{container} #{garage_bin} key create #{key_name} 2>&1`

      if key_output.include?("Key ID:")
        puts "✓ Created API key"

        key_id = key_output.match(/Key ID:\s*(\S+)/)&.[](1)
        secret_key = key_output.match(/Secret key:\s*(\S+)/)&.[](1)

        if key_id && secret_key
          puts ""
          puts "  Key ID: #{key_id}"
          puts "  Secret Key: #{secret_key}"
        end
      else
        puts "⚠  Key may already exist"
      end

      # Grant access
      puts "Granting access..."
      allow_result = system("docker exec #{container} #{garage_bin} bucket allow --read --write --owner #{bucket} --key #{key_name}")
      puts allow_result ? "✓ Access granted" : "⚠  Access may already be granted"
    end

    puts ""
    puts "All environments configured! Set the appropriate credentials for each environment:"
    puts "  export GARAGE_ACCESS_KEY=<key_id>"
    puts "  export GARAGE_SECRET_KEY=<secret_key>"
  end

  desc "Show Garage cluster status"
  task status: :environment do
    container = "ei_pointofsale_garage"
    garage_bin = "/garage"

    puts "Garage Cluster Status:"
    puts "=" * 50
    system("docker exec #{container} #{garage_bin} status")

    puts ""
    puts "Buckets:"
    puts "=" * 50
    system("docker exec #{container} #{garage_bin} bucket list")

    puts ""
    puts "Keys:"
    puts "=" * 50
    system("docker exec #{container} #{garage_bin} key list")
  end
end
