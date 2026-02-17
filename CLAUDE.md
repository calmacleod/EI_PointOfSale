# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Shell Environment

This project uses **mise** for runtime version management. Prefix shell commands with:
```bash
source ~/.zshrc && eval "$(mise activate zsh)" && <command>
```

## Common Commands

```bash
# Development server (web + CSS watcher + Solid Queue workers)
bin/dev

# Run all tests
bin/rails test

# Run a single test file
bin/rails test test/controllers/products_controller_test.rb

# Run a single test by line number
bin/rails test test/controllers/products_controller_test.rb:42

# Run system tests (browser-based)
bin/rails test:system

# Linting
bin/rubocop              # Ruby/Rails
bin/rubocop -a           # Auto-fix safe violations
bundle exec herb analyze app --no-log-file  # ERB analysis
npm run herb:lint        # ERB lint

# Security
bin/bundler-audit
bin/brakeman --quiet --no-pager
bin/importmap audit

# Full CI pipeline (setup, lint, security, tests, seed validation)
bin/ci

# Database
bin/rails db:migrate
bin/rails db:seed
env RAILS_ENV=test bin/rails db:seed:replant  # Reseed test DB
```

## Tech Stack

- **Ruby 4.0 / Rails 8.1** with Propshaft asset pipeline and Importmap for JS
- **PostgreSQL** with multi-database setup (primary, queue, cable, cache)
- **Tailwind CSS** for styling
- **Hotwire** (Stimulus + Turbo) for interactivity
- **Solid Queue / Solid Cache / Solid Cable** for jobs, caching, Action Cable
- **Minitest** for testing (not RSpec)
- **Rubocop Rails Omakase** for linting

## Architecture

### Authentication & Authorization
- **Custom session-based auth** via `Authentication` concern — not Devise or JWT
- `Current.user` (via `ActiveSupport::CurrentAttributes`) provides the signed-in user
- **CanCanCan** for authorization (not Pundit) — rules defined in `app/models/ability.rb`
- **STI** for user roles: `User` base class with `Admin` and `Common` subclasses (check with `user.is_a?(Admin)`)
- Admin-only controllers live in `AdminArea::` namespace with `require_admin` before_action

### Controller Patterns
- All controllers extend `ApplicationController` which includes `Authentication`
- Use `load_and_authorize_resource` for resource controllers
- Strong params in private `*_params` methods
- Use `allow_unauthenticated_access` for public actions
- Redirect with `notice:` or `alert:` flash messages

### Model Patterns
- `normalizes` for attribute cleaning (emails, etc.)
- `Discard::Model` for soft deletes (not `acts_as_paranoid`)
- `PgSearch::Model` for full-text search (trigram + tsearch)
- `audited` for change tracking
- `Sellable` concern shared by `Product` and `Service` — polymorphic via `OrderLine.sellable`
- Order state machine: enum-based (`draft → held → completed → voided/refunded`)

### Service Layer
- Business logic in `app/services/`, namespaced (e.g., `Orders::CalculateTotals`, `Orders::Complete`)
- Order services handle state transitions, totals recalculation, refund processing

### Background Jobs
- Solid Queue with recurring jobs configured in `config/recurring.yml`
- Dashboard metrics refresh (15 min), nightly backups (DB at 2am, MinIO at 3am), daily notifications

### Testing Conventions
- Integration tests in `test/controllers/`, unit tests in `test/models/`, service tests in `test/services/`
- Use `sign_in_as(user)` helper from `SessionTestHelper` for authenticated requests
- Use fixtures (not factories) — all fixtures loaded automatically
- Tests run in parallel by default
- `DUMMY_PNG` constant available in test cases for stubbing chart rendering

### Views
- Tailwind CSS utility classes; conditional classes with `class: [...].join(" ")`
- Shared UI partials in `app/views/shared/`
- Use `*_path` helpers (not `*_url`) for in-app links

## Linting & Style
- Run `bin/rubocop` after substantial changes and fix all violations before considering work complete
- Run `bin/rubocop -a` for auto-fix, then manually fix remaining issues
