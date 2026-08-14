# AGENTS.md

## Shell Setup

- **mise** manages Ruby (4.0.1); **nvm** manages Node
- Prefix every command:
  - Ruby/Rails: `source ~/.zshrc && eval "$(mise activate zsh)" && <cmd>`
  - Node/npx:  `source ~/.zshrc && nvm use && <cmd>`

## Key Commands

```bash
bin/dev                          # Start Rails, Vite, and jobs
bin/rails test                   # Full suite
bin/rails test path/to/file:42   # Single test
bin/rails test:system            # System/browser tests
bin/rubocop                      # Lint
bin/rubocop -a                   # Auto-fix safe violations
bin/steep check                  # Type-check the adopted service-layer slice
bin/ci                           # Full CI pipeline
npm run herb:lint                # ERB lint (@herb-tools/linter)
npm run tailwind:lint            # Tailwind class lint
npm run lint:svelte              # Svelte type/component checks
npm run build                    # Production Vite build
env RAILS_ENV=test bin/rails db:seed:replant  # Reset test DB
```

## Stack

- **Ruby 4.0.1 / Rails 8.1** — Inertia Rails, Vite Ruby, Svelte 5, Tailwind
- **PostgreSQL** — multi-DB (primary, queue, cable, cache)
- **Solid Queue / Solid Cache / Solid Cable**
- **Minitest** (not RSpec), fixtures (not factories)
- **Rubocop Rails Omakase**

## Architecture

### Auth & Authorization
- `Authentication` concern + `Current.user`; `allow_unauthenticated_access` for public actions
- **CanCanCan** — `app/models/ability.rb`
- STI: `Admin` and `Common` extend `User`; admin controllers under `AdminArea::` namespace

### Controllers
- `load_and_authorize_resource` on resource controllers

### Models
- `normalizes` for attribute cleaning; `Discard::Model` for soft deletes
- `PgSearch::Model` for full-text search; `audited` for change tracking
- `Sellable` concern — `OrderLine.sellable` is polymorphic (Product, Service, GiftCertificate)
- Order state: `draft → held → completed → voided/refunded`

### Services
- Business logic in `app/services/` (e.g. `Orders::CalculateTotals`, `Orders::Complete`)

### Background Jobs
- Recurring jobs: `config/recurring.yml`

## Testing
- Sign in: `sign_in_as(user)` from `SessionTestHelper`
- Fixtures: `admin` (Admin), `one`/`two` (Common users); tax codes `one` (HST/0.13), `two` (EXEMPT/0)
- `DUMMY_PNG` constant for chart stubs; tests run in parallel
- Use `*_path` helpers (not `*_url`)

## Frontend
- Inertia page props are assembled by `Ui::PagePresenter`; the shared Svelte entrypoint is `app/javascript/pages/page.svelte`
- Reusable screen components live under `app/javascript/pages/components/`
- Tailwind utility classes and shared `ui-*` component classes are defined from the Vite entrypoint
- Pagy remains server-owned and is serialized into Inertia pagination props

## Ruby Type Checking

- Steep checks only the service files listed in `Steepfile`; the rest of the Rails app remains unchecked Ruby
- Application signatures live in `sig/services/`; Rails-generated model signatures live in `sig/rbs_rails/`
- Run `bundle exec rbs_rails models` after schema or model macro changes, then run `bin/steep check`
- Run `bundle exec rbs collection update` after changing Ruby dependencies

## Offline Lookup

The `/offline` screen is part of the primary Inertia/Svelte frontend. It provides read-only product, service, customer, and tax-code lookup from IndexedDB when Rails is unavailable.
- `app/javascript/lib/offline-catalog.js` owns IndexedDB and delta/full sync
- Sync endpoints live under `/api/v1/*/sync` and use same-origin authentication
- The primary Vite entrypoint registers the service worker and warms the page, assets, and catalog while online
- The service worker falls back to the cached native `/offline` page; no separate offline build is required
