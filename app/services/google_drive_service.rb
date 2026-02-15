# frozen_string_literal: true

require "google/apis/drive_v3"
require "googleauth"

# Uploads files to a Google Drive folder using OAuth 2.0 (personal accounts).
#
# Setup:
#   1. Create OAuth client credentials in Google Cloud Console
#   2. Set GOOGLE_CLIENT_ID, GOOGLE_CLIENT_SECRET, and GOOGLE_DRIVE_BACKUP_FOLDER_ID
#   3. Visit Admin > Backups and click "Connect Google Drive" to authorize
#   4. The refresh token is stored in config/credentials/google_oauth_token.json
#
# Usage:
#   GoogleDriveService.upload("/tmp/backup.sql.gz", content_type: "application/gzip")
#
class GoogleDriveService
  SCOPE = "https://www.googleapis.com/auth/drive.file"
  TOKEN_PATH = Rails.root.join("config/credentials/google_oauth_token.json")

  class Error < StandardError; end

  class << self
    # Uploads a local file to the configured Google Drive folder.
    def upload(file_path, content_type: "application/octet-stream", folder_id: nil)
      validate_config!

      target_folder = folder_id || ENV.fetch("GOOGLE_DRIVE_BACKUP_FOLDER_ID")
      file_name = File.basename(file_path)

      metadata = Google::Apis::DriveV3::File.new(
        name: file_name,
        parents: [ target_folder ]
      )

      drive_service.create_file(
        metadata,
        upload_source: file_path,
        content_type: content_type,
        fields: "id, name, size, created_time"
      )
    end

    # Lists backup files in the configured Google Drive folder.
    def list_files(prefix: nil, folder_id: nil)
      validate_config!

      target_folder = folder_id || ENV.fetch("GOOGLE_DRIVE_BACKUP_FOLDER_ID")

      query = "'#{target_folder}' in parents and trashed = false"
      query += " and name contains '#{prefix}'" if prefix.present?

      response = drive_service.list_files(
        q: query,
        fields: "files(id, name, size, created_time)",
        order_by: "createdTime desc",
        page_size: 100
      )

      response.files || []
    end

    # Downloads a Drive file and returns a StringIO.
    def download(file_id)
      validate_config!

      drive_service.get_file(file_id, download_dest: StringIO.new)
    end

    # Checks whether the Google Drive integration is configured and connected.
    #
    # @return [Hash] { configured: Boolean, connected: Boolean, error: String|nil, email: String|nil }
    def check_credentials
      unless oauth_configured?
        return { configured: false, connected: false, error: "OAuth client credentials not set (GOOGLE_CLIENT_ID, GOOGLE_CLIENT_SECRET)" }
      end

      unless ENV["GOOGLE_DRIVE_BACKUP_FOLDER_ID"].present?
        return { configured: false, connected: false, error: "GOOGLE_DRIVE_BACKUP_FOLDER_ID not set" }
      end

      unless token_stored?
        return { configured: true, connected: false, error: "Not connected — click \"Connect Google Drive\" to authorize" }
      end

      # Make a lightweight API call to verify the token still works
      reset!
      about = drive_service.get_about(fields: "user(emailAddress, displayName)")
      {
        configured: true,
        connected: true,
        error: nil,
        email: about.user.email_address,
        display_name: about.user.display_name
      }
    rescue Google::Apis::AuthorizationError
      { configured: true, connected: false, error: "Authorization expired — reconnect Google Drive" }
    rescue StandardError => e
      { configured: true, connected: false, error: e.message }
    ensure
      reset!
    end

    # Removes old backups, keeping the most recent N.
    def prune(prefix:, keep: 7, folder_id: nil)
      validate_config!

      target_folder = folder_id || ENV.fetch("GOOGLE_DRIVE_BACKUP_FOLDER_ID")

      query = "'#{target_folder}' in parents and name contains '#{prefix}' and trashed = false"
      response = drive_service.list_files(
        q: query,
        fields: "files(id, name, created_time)",
        order_by: "createdTime desc"
      )

      files_to_delete = response.files.drop(keep)
      files_to_delete.each do |file|
        drive_service.delete_file(file.id)
        Rails.logger.info { "[GoogleDriveService] Pruned old backup: #{file.name}" }
      end

      files_to_delete.size
    end

    # ── OAuth flow helpers ──

    # Builds the Google OAuth authorization URL for the consent screen.
    def authorization_url(redirect_uri:)
      client = build_oauth_client(redirect_uri)
      client.authorization_uri(
        access_type: "offline",
        prompt: "consent",
        scope: SCOPE
      ).to_s
    end

    # Exchanges an authorization code for tokens and stores the refresh token.
    def exchange_code(code:, redirect_uri:)
      client = build_oauth_client(redirect_uri)
      client.code = code
      client.fetch_access_token!

      store_token(client)
      true
    end

    # Removes the stored OAuth token (disconnect).
    def disconnect!
      FileUtils.rm_f(TOKEN_PATH)
      reset!
    end

    # Whether OAuth client credentials are set.
    def oauth_configured?
      ENV["GOOGLE_CLIENT_ID"].present? && ENV["GOOGLE_CLIENT_SECRET"].present?
    end

    # Whether a refresh token is stored on disk.
    def token_stored?
      TOKEN_PATH.exist?
    end

    private

      def drive_service
        @drive_service ||= begin
          service = Google::Apis::DriveV3::DriveService.new
          service.authorization = load_credentials
          service
        end
      end

      def load_credentials
        raise Error, "No OAuth token stored — authorize via Admin > Backups first" unless token_stored?

        token_data = JSON.parse(TOKEN_PATH.read)
        client = build_oauth_client
        client.refresh_token = token_data["refresh_token"]
        client.fetch_access_token!
        client
      end

      def build_oauth_client(redirect_uri = nil)
        Signet::OAuth2::Client.new(
          client_id: ENV.fetch("GOOGLE_CLIENT_ID"),
          client_secret: ENV.fetch("GOOGLE_CLIENT_SECRET"),
          authorization_uri: "https://accounts.google.com/o/oauth2/auth",
          token_credential_uri: "https://oauth2.googleapis.com/token",
          redirect_uri: redirect_uri,
          scope: SCOPE
        )
      end

      def store_token(client)
        TOKEN_PATH.dirname.mkpath

        token_data = {
          refresh_token: client.refresh_token,
          stored_at: Time.current.iso8601
        }

        TOKEN_PATH.write(JSON.pretty_generate(token_data))
        TOKEN_PATH.chmod(0o600)

        Rails.logger.info { "[GoogleDriveService] OAuth token stored at #{TOKEN_PATH}" }
      end

      def validate_config!
        unless oauth_configured?
          raise Error, "GOOGLE_CLIENT_ID and GOOGLE_CLIENT_SECRET environment variables are not set"
        end

        unless ENV["GOOGLE_DRIVE_BACKUP_FOLDER_ID"].present?
          raise Error, "GOOGLE_DRIVE_BACKUP_FOLDER_ID environment variable is not set"
        end

        unless token_stored?
          raise Error, "Google Drive not connected — authorize via Admin > Backups"
        end
      end

      def reset!
        @drive_service = nil
      end
  end
end
