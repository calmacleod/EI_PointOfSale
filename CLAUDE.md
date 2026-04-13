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

- **Ruby 4.0 / Rails 8.1** — Propshaft, Importmap, Tailwind, Hotwire (Turbo + Stimulus)
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

### Views
- Tailwind utility classes; conditional: `class: [...].join(" ")`
- Shared partials in `app/views/shared/`
- Use `*_path` helpers (not `*_url`)
- Pagy: include `Pagy::Method` in controllers; render `shared/pagy_nav` partial in views

## Offline / Svelte App

A standalone **Svelte 5** SPA that provides an offline-capable product/service/customer lookup tool. It is separate from the main Rails UI and serves as a reference tool for staff when the server is unreachable.

### Purpose
- Staff can look up products, services, tax codes, and customers without a live server connection
- Data is synced from Rails into the browser's **IndexedDB** (via a service worker pattern)
- Built and served as static files at `/offline/` on the Rails server

### Structure
```
svelte/
  main.js           # SPA entry point
  sync-worker.js    # Background sync worker
  vite.config.mjs   # Builds into public/offline/
  lib/
    db.js           # IndexedDB helpers
    sync.js         # Sync logic (fetches from Rails API)
  components/
    App.svelte      # Root layout + navigation state
    Sidebar.svelte
    SearchBar.svelte
    ProductList.svelte / ProductCard.svelte
    ServiceCard.svelte / ServicesPage.svelte
    CustomersPage.svelte / CustomerCard.svelte
    TaxCodesPage.svelte / TaxCodeCard.svelte
    SyncStatus.svelte
```

### Rails Integration
- Sync endpoint: `GET /api/v1/products/sync` — accepts `?since=<timestamp>` for incremental sync
- Returns `{ products: [...], synced_at: "..." }` JSON
- Auth: uses same-origin session cookies (`credentials: "same-origin"`)
- Built output lands in `public/offline/` (served as static assets by Rails/Propshaft)

### Build Commands
```bash
source ~/.zshrc && nvm use && npm run offline:build   # Production build
source ~/.zshrc && nvm use && npm run offline:dev     # Watch mode
```

## WASM Build & Deploy

The WASM module (`public/app.wasm`) embeds the full Rails app compiled to WebAssembly. It powers order calculations in the offline Svelte app via an in-browser PGlite database.

### Rebuild & deploy

```bash
bin/build_wasm        # Build app.wasm + Svelte offline app
bin/kamal deploy      # Deploy to production (Docker image picks up public/ changes)
```

### When to rebuild

| Changed | Run |
|---------|-----|
| Ruby app code (`app/`, `config/`, `lib/`, `db/schema.rb`) | `bin/build_wasm` |
| Gem dependencies (`Gemfile`) | `bin/build_wasm` (full recompile) |
| Svelte source only (`svelte/`) | `bin/build_wasm --svelte` |

The `--svelte` flag skips the slow Ruby WASM compile (~10–30 min first time, faster on
subsequent builds because `tmp/wasmify/ruby-core.wasm` is cached).

### Pipeline internals

1. `bin/rails wasmify:pack` — compiles Rails → `dist/app.wasm` using the Ruby 3.3 WASM toolchain
2. `cp dist/app.wasm public/app.wasm` — moves it into the static assets dir
3. `npm run offline:build` — Vite bundles the Svelte SPA into `public/offline/`
4. `bin/kamal deploy` — builds the Docker image (which includes `public/`) and pushes to production

### WASM environment notes

- Rails runs with `RAILS_ENV=wasm` (see `config/environments/wasm.rb`)
- Job adapter is `:inline`; PgSearch callbacks are skipped (`Rails.env.wasm?` guard in `AsyncPgSearch`)
- No Solid Queue / Solid Cache / Solid Cable — those DB connections are disabled
- Database is PGlite (in-browser Postgres); schema is loaded fresh on each boot
- Only `db/schema.rb` is loaded — migrations are not run
