# EI Point of Sale

A Rails 8 point-of-sale application for managing products, services, customers, and inventory.

## Tech Stack

- **Ruby 4.0**, **Rails 8.1**
- **PostgreSQL** with PgSearch for full-text search
- **Inertia Rails** with a **Svelte 5** frontend
- **Vite** and **Tailwind CSS** for frontend builds and styling
- **Solid Queue** for background jobs
- **CanCanCan** for authorization
- **Audited** for change tracking

---

## Quick Start

### Prerequisites

- Ruby 4.0.1
- PostgreSQL
- Node.js (for the Svelte/Vite frontend and linters)

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

# Create and migrate the database
bin/rails db:create db:migrate

# Load development data (optional)
bin/rails db:seed
```

### Run the app

```bash
bin/dev
```

This starts Rails, the Vite frontend server, and Solid Queue workers. Open [http://localhost:3000](http://localhost:3000).

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
| **Backups** | Nightly database and Garage object-storage backups to Google Drive. OAuth 2.0 integration managed from Admin > Backups. |
| **Profile** | Edit contact info, theme (light/dark/dim), font size, sidebar preference, and dashboard metric selection. |
| **Search** | Global search across products, services, customers, users, and more. |

---

## Local Development

### PostgreSQL connection

When running Solid Queue locally (`bin/dev` or `bin/jobs`), set `PGGSSENCMODE=disable` so the `pg` gem can connect without GSSAPI. Add to `.env`:

```
PGGSSENCMODE=disable
```

### CI and linting

```bash
# Run tests
bin/rails test

# Lint
bin/rubocop
npm run herb:lint
npm run tailwind:lint
npm run lint:svelte
bundle exec herb analyze app

# Production frontend build
npm run build

# Full CI suite (tests, lint, security)
bin/ci
```

---

## Environment Variables

| Variable | Description |
|----------|-------------|
| `RAILS_ENV` | Rails environment (development, test, production) |
| `APP_URL` | Canonical app URL used for production links and password reset emails |
| `PGGSSENCMODE` | Set to `disable` for local PostgreSQL with Solid Queue |
| `GARAGE_ACCESS_KEY` | Garage/S3 access key for object storage |
| `GARAGE_SECRET_KEY` | Garage/S3 secret key for object storage |
| `GARAGE_ENDPOINT` | Garage/S3 endpoint |
| `GOOGLE_CLIENT_ID` | Google OAuth 2.0 client ID for Drive backups |
| `GOOGLE_CLIENT_SECRET` | Google OAuth 2.0 client secret for Drive backups |
| `GOOGLE_DRIVE_BACKUP_FOLDER_ID` | Google Drive folder ID where backups are stored |
| `GOOGLE_DRIVE_TOKEN_PATH` | Persistent path for the Google OAuth refresh token |
| `SMTP_ADDRESS` | SMTP server for password reset emails |
| `SMTP_USERNAME` | SMTP username |
| `SMTP_PASSWORD` | SMTP password |
| `MAILER_FROM` | From address for application emails |
| `VAPID_PUBLIC_KEY` | VAPID public key for Web Push notifications |
| `VAPID_PRIVATE_KEY` | VAPID private key for Web Push notifications |
| `VAPID_CONTACT` | VAPID contact URI (e.g. `mailto:admin@example.com`) |
| `DEV_ADMIN_EMAIL` | Admin email for development seeds (optional) |
| `DEV_ADMIN_PASSWORD` | Admin password for development seeds (optional) |
| `DEV_ADMIN_NAME` | Admin display name for development seeds (optional) |

See `env.template` for a full list.

---

### Google Drive backups (optional)

Nightly backups of the database and Garage bucket are uploaded to Google Drive. Setup requires a Google Cloud project with OAuth 2.0 credentials. See [docs/google-drive-backups.md](docs/google-drive-backups.md) for full instructions.

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
