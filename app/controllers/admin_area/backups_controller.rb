# frozen_string_literal: true

module AdminArea
  class BackupsController < BaseController
    def show
      @credentials = GoogleDriveService.check_credentials
      @db_backups = fetch_backups("db_backup_")
      @garage_backups = fetch_backups("garage_backup_")
      @last_db_backup = @db_backups.first
      @last_garage_backup = @garage_backups.first
    rescue GoogleDriveService::Error => e
      @credentials_error = e.message
      @db_backups = []
      @garage_backups = []
    end

    def download
      file_id = params[:file_id]
      file_name = params[:file_name] || "backup"

      content = GoogleDriveService.download(file_id)
      content.rewind

      send_data content.read,
        filename: file_name,
        type: "application/octet-stream",
        disposition: "attachment"
    rescue Google::Apis::ClientError => e
      redirect_to admin_backups_path, alert: "Download failed: #{e.message}"
    end

    # Redirects the admin to Google's OAuth consent screen.
    def authorize
      redirect_uri = oauth_callback_admin_backups_url
      url = GoogleDriveService.authorization_url(redirect_uri: redirect_uri)
      redirect_to url, allow_other_host: true
    end

    # Google redirects back here with an authorization code.
    def oauth_callback
      code = params[:code]

      if code.blank?
        redirect_to admin_backups_path, alert: "Authorization was cancelled or failed."
        return
      end

      redirect_uri = oauth_callback_admin_backups_url
      GoogleDriveService.exchange_code(code: code, redirect_uri: redirect_uri)
      redirect_to admin_backups_path, notice: "Google Drive connected successfully."
    rescue StandardError => e
      redirect_to admin_backups_path, alert: "Authorization failed: #{e.message}"
    end

    # Removes the stored OAuth token.
    def disconnect
      GoogleDriveService.disconnect!
      redirect_to admin_backups_path, notice: "Google Drive disconnected."
    end

    private

      def fetch_backups(prefix)
        return [] unless @credentials[:connected]

        GoogleDriveService.list_files(prefix: prefix)
      rescue StandardError => e
        Rails.logger.error { "[BackupsController] Failed to list #{prefix} files: #{e.message}" }
        []
      end
  end
end
