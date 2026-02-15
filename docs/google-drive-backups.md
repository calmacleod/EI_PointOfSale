# Google Drive Backups

## Overview

The application performs **nightly automated backups** of both the PostgreSQL database and the MinIO object storage bucket. Backups are compressed and uploaded to a Google Drive folder using OAuth 2.0 (works with personal Google accounts). Old backups are automatically pruned to retain the most recent 7 of each type.

| Job                  | Schedule     | What it backs up                        | File format       |
|----------------------|--------------|-----------------------------------------|--------------------|
| `DatabaseBackupJob`  | 2:00 AM daily | Primary PostgreSQL database (`pg_dump`) | `.dump.gz`         |
| `MinioBackupJob`     | 3:00 AM daily | All objects in the MinIO bucket         | `.tar.gz`          |

Both jobs run via **Solid Queue** recurring tasks defined in `config/recurring.yml`.

---

## Prerequisites

- A Google account (personal Gmail is fine)
- Access to the [Google Cloud Console](https://console.cloud.google.com/)
- `pg_dump` available on the server (included with PostgreSQL client tools)

---

## Step 1: Create a Google Cloud Project

1. Go to [console.cloud.google.com](https://console.cloud.google.com/)
2. Click the project dropdown at the top and select **New Project**
3. Name it something like `EI PointOfSale Backups`
4. Click **Create**
5. Make sure the new project is selected in the project dropdown

---

## Step 2: Enable the Google Drive API

1. In the Cloud Console, go to **APIs & Services > Library**
2. Search for **Google Drive API**
3. Click on it and press **Enable**

---

## Step 3: Configure the OAuth Consent Screen

1. Go to **APIs & Services > OAuth consent screen**
2. Select **External** user type and click **Create**
3. Fill in the required fields:
   - **App name**: `EI POS Backups` (or similar)
   - **User support email**: your email
   - **Developer contact email**: your email
4. Click **Save and Continue**
5. On the **Scopes** step, click **Add or Remove Scopes**, search for `drive.file`, select it, and click **Update**
6. Click **Save and Continue**
7. On the **Test users** step, add your Google email address
8. Click **Save and Continue**, then **Back to Dashboard**

> **Note**: While the app is in "Testing" status, only the test users you add can authorize it. This is fine for a backup tool used by one person. You do **not** need to publish it.

---

## Step 4: Create OAuth Client Credentials

1. Go to **APIs & Services > Credentials**
2. Click **Create Credentials > OAuth client ID**
3. Select **Web application** as the application type
4. Name it `EI POS Backups`
5. Under **Authorized redirect URIs**, add:
   - For development: `http://localhost:3000/admin/backups/oauth_callback`
   - For production: `https://yourdomain.com/admin/backups/oauth_callback`
6. Click **Create**
7. Copy the **Client ID** and **Client Secret**

---

## Step 5: Create a Google Drive Backup Folder

1. Go to [drive.google.com](https://drive.google.com/)
2. Create a new folder (e.g., `EI POS Backups`)
3. Open the folder and copy the **folder ID** from the URL:
   ```
   https://drive.google.com/drive/folders/1aBcDeFgHiJkLmNoPqRsTuVwXyZ
                                          ^^^^^^^^^^^^^^^^^^^^^^^^^^^
                                          This is the folder ID
   ```

---

## Step 6: Configure Environment Variables

Add the following to your `.env` file (development) or your production environment/secrets:

```bash
# OAuth 2.0 client credentials from Step 4
GOOGLE_CLIENT_ID=123456789-abcdef.apps.googleusercontent.com
GOOGLE_CLIENT_SECRET=GOCSPX-your-secret-here

# The Google Drive folder ID from Step 5
GOOGLE_DRIVE_BACKUP_FOLDER_ID=1aBcDeFgHiJkLmNoPqRsTuVwXyZ
```

---

## Step 7: Connect Google Drive

1. Start your Rails app and sign in as an admin
2. Go to **Admin Settings > Backups**
3. You should see a "Not connected" status with a **Connect Google Drive** button
4. Click the button — you'll be redirected to Google's consent screen
5. Sign in with your Google account and grant access
6. You'll be redirected back to the Backups page showing "Connected" with your email

The app now stores a refresh token at `config/credentials/google_oauth_token.json` (gitignored). This token is long-lived and will be used for all future backup uploads.

---

## Step 8: Verify the Setup

You can test the backup jobs manually from the Rails console:

```ruby
# Test database backup
DatabaseBackupJob.perform_now

# Test MinIO backup
MinioBackupJob.perform_now
```

After running, check the Google Drive folder — you should see files like:
- `db_backup_20260215_020000.dump.gz`
- `minio_backup_20260215_030000.tar.gz`

---

## How It Works

### Authentication

The app uses **OAuth 2.0** with an offline refresh token. This means:

- You authenticate once via the browser (the "Connect Google Drive" flow)
- The app stores a refresh token on disk
- Background jobs use the refresh token to get short-lived access tokens automatically
- No service account or Google Workspace required — works with a free personal Gmail

### GoogleDriveService

The shared service (`app/services/google_drive_service.rb`) handles:

- **`GoogleDriveService.upload(file_path, content_type:)`** — Uploads a local file to the configured Drive folder
- **`GoogleDriveService.list_files(prefix:)`** — Lists files in the folder, optionally filtered by prefix
- **`GoogleDriveService.download(file_id)`** — Downloads a file as a StringIO stream
- **`GoogleDriveService.prune(prefix:, keep:)`** — Deletes old backups beyond the retention count
- **`GoogleDriveService.check_credentials`** — Verifies OAuth config and token validity
- **`GoogleDriveService.authorization_url(redirect_uri:)`** — Generates the OAuth consent URL
- **`GoogleDriveService.exchange_code(code:, redirect_uri:)`** — Exchanges auth code for tokens
- **`GoogleDriveService.disconnect!`** — Removes the stored token

### DatabaseBackupJob

1. Runs `pg_dump` with custom format (`-Fc`) against the primary database
2. Compresses the dump with gzip
3. Uploads the `.dump.gz` file to Google Drive
4. Prunes old database backups (keeps 7)
5. Cleans up local temp files (even on failure)

### MinioBackupJob

1. Lists all objects in the configured MinIO bucket
2. Downloads each object and writes it into a `.tar.gz` archive
3. Uploads the archive to Google Drive
4. Prunes old MinIO backups (keeps 7)
5. Cleans up local temp files (even on failure)

---

## Admin Backups Page

The admin backups page at `/admin/backups` shows:

- **Integration status** — whether Google Drive is connected, with the account email
- **Connect / Disconnect** buttons for managing the OAuth connection
- **Last backup summary** — when the most recent DB and MinIO backups ran
- **Full file tables** — all backup files with name, date, size, and download links

---

## Restoring from Backup

### Database

```bash
# Download the backup from the admin page or Google Drive, then:
gunzip db_backup_20260215_020000.dump.gz
pg_restore -h localhost -U postgres -d ei_point_of_sale_production db_backup_20260215_020000.dump
```

### MinIO / Object Storage

```bash
# Download and extract the archive:
tar xzf minio_backup_20260215_030000.tar.gz -C /path/to/restore/

# Then use the MinIO client (mc) or AWS CLI to re-upload:
mc cp --recursive /path/to/restore/ minio/ei-pointofsale-production/
```

---

## Troubleshooting

| Problem | Solution |
|---------|----------|
| "Not configured" on backups page | Set `GOOGLE_CLIENT_ID`, `GOOGLE_CLIENT_SECRET`, and `GOOGLE_DRIVE_BACKUP_FOLDER_ID` in `.env` and restart |
| "Not connected" on backups page | Click **Connect Google Drive** and complete the OAuth flow |
| `Google::Apis::AuthorizationError` | The refresh token may have expired or been revoked — click **Disconnect** then **Connect Google Drive** again |
| `Google::Apis::ClientError: insufficientPermissions` | Make sure the Drive API is enabled (Step 2) and the OAuth scope includes `drive.file` |
| Google shows "This app isn't verified" warning | This is normal for apps in "Testing" mode — click **Continue** (you added yourself as a test user in Step 3) |
| `pg_dump failed` | Ensure `pg_dump` is installed and the database credentials in `database.yml` are correct |
| Backups not running on schedule | Verify Solid Queue is running and check `config/recurring.yml` has the production entries |
| Refresh token stops working | Google revokes tokens if the app stays in "Testing" mode and the token is older than 7 days — either re-authorize periodically, or publish the OAuth consent screen (no review needed for `drive.file` scope) |
