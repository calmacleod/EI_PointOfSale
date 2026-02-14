# Ei Point of Sale

## Local CI & Signoff

Run the full CI suite locally (tests, lint, security scans) and sign off on PRs when everything passes:

```bash
bin/ci
```

When all steps pass, `gh signoff` runs automatically to set a green GitHub commit status on your PR.

### One-time setup for local CI

- **Node.js** (for Herb ERB linter): `brew install node` then `npm install`
- **GitHub CLI** (for signoff): `brew install gh`, then `gh auth login`, then `gh extension install basecamp/gh-signoff`

### Require signoff for merges

To require a signoff before PRs can be merged:

```bash
gh signoff install
```

---

## Documentation

- **[Search (pg_search)](docs/search.md)** — Full-text search across Product, Service, Category, Supplier, User, ProductVariant, TaxCode
- [Products and variants](docs/products-and-variants.md)
- [Services](docs/services.md)
- [Style guide](docs/styleguide.md)

---

Things you may want to cover:

* Ruby version

* System dependencies

* Configuration

* Database creation

* Database initialization

* How to run the test suite

* Services (job queues, cache servers, search engines, etc.)

* Deployment instructions

* ...
