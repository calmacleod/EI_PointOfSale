# CLAUDE.md

Guidance for Claude Code when working in this repository.

## Shell Environment

Uses **mise** for Ruby/Rails, **nvm** for Node. Prefix commands:
```bash
source ~/.zshrc && eval "$(mise activate zsh)" && <command>
source ~/.zshrc && nvm use && <command>   # for node/npx
```

## Common Commands

```bash
bin/dev                          # Dev server (web + CSS + Solid Queue)
bin/rails test                   # All tests
bin/rails test path/to/test:42   # Single test by line
bin/rails test:system            # System (browser) tests
bin/rubocop                      # Lint (run after substantial changes)
bin/rubocop -a                   # Auto-fix safe violations
bin/ci                           # Full CI pipeline
bin/rails db:migrate
bin/rails db:seed
env RAILS_ENV=test bin/rails db:seed:replant
```

## Tech Stack

- **Ruby 4.0 / Rails 8.1** — Inertia Rails, Vite Ruby, Svelte 5, Tailwind
- **PostgreSQL** — multi-database (primary, queue, cable, cache)
- **Solid Queue / Solid Cache / Solid Cable**
- **Minitest** (not RSpec), fixtures (not factories)
- **Rubocop Rails Omakase**

## Architecture

### Auth & Authorization
- Custom session auth via `Authentication` concern; `Current.user`
- **CanCanCan** — rules in `app/models/ability.rb`
- STI roles: `Admin` and `Common` subclasses of `User`
- Admin controllers in `AdminArea::` namespace with `require_admin`

### Controllers
- Extend `ApplicationController` (includes `Authentication`)
- `load_and_authorize_resource` for resource controllers
- `allow_unauthenticated_access` for public actions

### Models
- `normalizes` for attribute cleaning
- `Discard::Model` for soft deletes
- `PgSearch::Model` for full-text search
- `audited` for change tracking
- `Sellable` concern — polymorphic via `OrderLine.sellable` (Product, Service, GiftCertificate)
- Order state machine: `draft → held → completed → voided/refunded`

### Services
- Business logic in `app/services/` (e.g. `Orders::CalculateTotals`, `Orders::Complete`)

### Background Jobs
- Recurring jobs in `config/recurring.yml` (metrics refresh, nightly backups, daily notifications)

### Testing
- `sign_in_as(user)` helper from `SessionTestHelper`
- Tests run in parallel; `DUMMY_PNG` constant for chart stubs
- Fixtures: `admin` (Admin), `one`/`two` (Common); tax codes `one` (HST/0.13), `two` (EXEMPT/0)

### Frontend
- Inertia page props are assembled by `Ui::PagePresenter`
- The shared Svelte page is `app/javascript/pages/page.svelte`; reusable screens live under `app/javascript/pages/components/`
- Tailwind utilities and shared `ui-*` classes are loaded from the Vite entrypoint
- Use `*_path` helpers (not `*_url`)
- Pagy remains server-owned and is serialized into Inertia pagination props

## Offline Lookup

The native Inertia/Svelte `/offline` screen provides read-only product, service, customer, and tax-code lookup when Rails is unreachable.

- IndexedDB and sync logic: `app/javascript/lib/offline-catalog.js`
- Native screen: `app/javascript/pages/components/OfflinePage.svelte`
- Sync endpoints: `/api/v1/products/sync`, `/api/v1/services/sync`, `/api/v1/customers/sync`, and `/api/v1/tax_codes/sync`
- Auth: uses same-origin session cookies (`credentials: "same-origin"`)
- The main Vite entrypoint warms the catalog and page while online; the service worker caches the native page and hashed Vite assets
- There is no separate offline build
