# EI Point of Sale

A Rails 8 point-of-sale application for managing products, services, customers, and inventory.

## Tech Stack

- **Ruby 4.0**, **Rails 8.1**
- **PostgreSQL** with PgSearch for full-text search
- **Tailwind CSS** for styling
- **Hotwire** (Turbo + Stimulus) for interactivity
- **Solid Queue** for background jobs
- **CanCanCan** for authorization
- **Audited** for change tracking

---

## Quick Start

### Prerequisites

- Ruby 4.0.1
- PostgreSQL
- Node.js (for Herb ERB linter)

### Setup

```bash
# Clone the repository
git clone <repository-url>
cd EI_PointOfSale

# Install dependencies
bundle install
npm install

# Copy environment template and configure
cp env.template .env
# Edit .env and set MAPBOX_ACCESS_TOKEN if you want address autocomplete

# Create and migrate the database
bin/rails db:create db:migrate

# Load development data (optional)
bin/rails db:seed
```

### Run the app

```bash
bin/dev
```

This starts the web server, Tailwind CSS watcher, and Solid Queue workers. Open [http://localhost:3000](http://localhost:3000).

### Sign in (development)

After seeding, use the credentials shown on the sign-in page (default: `admin@example.com` / `password123!`).

---

## Features

| Area | Description |
|------|-------------|
| **Dashboard** | Overview with configurable metrics (e.g. new customers). Metrics refresh every 15 minutes via background job. |
| **Products** | Catalog with variants, categories, tax codes, and suppliers. Full-text search. |
| **Services** | Sellable services with tax and optional categories. |
| **Customers** | Customer records with addresses, member numbers, and soft delete. |
| **Users** | Staff accounts (Admin only). Manage roles and activation. |
| **Admin** | Store settings, tax codes, suppliers, audit trail, backups. Mapbox address autofill for store address. |
| **Backups** | Nightly database and MinIO backups to Google Drive. OAuth 2.0 integration managed from Admin > Backups. |
| **Profile** | Edit contact info, theme (light/dark/dim), font size, sidebar preference, and dashboard metric selection. |
| **Search** | Global search across products, services, customers, users, and more. |

---

## Local Development

### PostgreSQL connection

When running Solid Queue locally (`bin/dev` or `bin/jobs`), set `PGGSSENCMODE=disable` so the `pg` gem can connect without GSSAPI. Add to `.env`:

```
PGGSSENCMODE=disable
```

### Address autocomplete (Mapbox)

Admin settings use Mapbox Address Autofill for the store address. Add your token to `.env`:

```
MAPBOX_ACCESS_TOKEN=pk.your_mapbox_public_token
```

Get a free token at [account.mapbox.com](https://account.mapbox.com/). Without it, the address field works as a normal text input.

### CI and linting

```bash
# Run tests
bin/rails test

# Lint
bin/rubocop
npx herb-lint
bundle exec herb analyze .

# Full CI suite (tests, lint, security)
bin/ci
```

---

## Environment Variables

| Variable | Description |
|----------|-------------|
| `RAILS_ENV` | Rails environment (development, test, production) |
| `PGGSSENCMODE` | Set to `disable` for local PostgreSQL with Solid Queue |
| `MAPBOX_ACCESS_TOKEN` | Mapbox public token for address autofill |
| `MINIO_ACCESS_KEY` | MinIO access key for local object storage |
| `MINIO_SECRET_KEY` | MinIO secret key for local object storage |
| `MINIO_ENDPOINT` | MinIO server URL (default: `http://localhost:9000`) |
| `GOOGLE_CLIENT_ID` | Google OAuth 2.0 client ID for Drive backups |
| `GOOGLE_CLIENT_SECRET` | Google OAuth 2.0 client secret for Drive backups |
| `GOOGLE_DRIVE_BACKUP_FOLDER_ID` | Google Drive folder ID where backups are stored |
| `VAPID_PUBLIC_KEY` | VAPID public key for Web Push notifications |
| `VAPID_PRIVATE_KEY` | VAPID private key for Web Push notifications |
| `VAPID_CONTACT` | VAPID contact URI (e.g. `mailto:admin@example.com`) |
| `DEV_ADMIN_EMAIL` | Admin email for development seeds (optional) |
| `DEV_ADMIN_PASSWORD` | Admin password for development seeds (optional) |
| `DEV_ADMIN_NAME` | Admin display name for development seeds (optional) |

See `env.template` for a full list.

---

### Google Drive backups (optional)

Nightly backups of the database and MinIO bucket are uploaded to Google Drive. Setup requires a Google Cloud project with OAuth 2.0 credentials. See [docs/google-drive-backups.md](docs/google-drive-backups.md) for full instructions.

Once configured, connect your Google account from **Admin Settings > Backups**.

---

## Documentation

- [Search (pg_search)](docs/search.md) — Full-text search
- [Products and variants](docs/products-and-variants.md)
- [Services](docs/services.md)
- [Google Drive backups](docs/google-drive-backups.md) — Nightly backup setup and troubleshooting
- [Notifications & Web Push](docs/notifications.md) — Real-time notifications and push setup
- [Style guide](docs/styleguide.md)

---

## Local CI & Signoff

Run the full CI suite and sign off on PRs when everything passes:

```bash
bin/ci
```

### One-time setup for local CI

- **Node.js** (for Herb ERB linter): `brew install node` then `npm install`
- **GitHub CLI** (for signoff): `brew install gh`, then `gh auth login`, then `gh extension install basecamp/gh-signoff`

### Require signoff for merges

```bash
gh signoff install
```
