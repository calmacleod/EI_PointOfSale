# Full-Text Search (pg_search)

This app uses [pg_search](https://github.com/Casecommons/pg_search) for PostgreSQL full-text search. Search is available both globally (across all models) and per-model.

## Requirements

- PostgreSQL with `pg_trgm` extension enabled (migration: `EnablePostgresExtensions`)
- `pg_search_documents` table (migration: `CreatePgSearchDocuments`)

## Searchable Models

| Model           | Global search fields          | Model scope           | Discarded excluded |
|----------------|-------------------------------|-----------------------|--------------------|
| Product        | `name`                        | `Product.search(q)`   | ✓                  |
| Service        | `name`, `code`, `description` | `Service.search(q)`   | ✓                  |
| Category       | `name`                        | `Category.search(q)`  | ✓                  |
| Supplier       | `name`, `phone`               | `Supplier.search(q)`  | ✓                  |
| User           | `name`, `email_address`, `notes` | `User.search(q)`   | —                  |
| ProductVariant | `name`, `code`, `notes`       | `ProductVariant.search(q)` | ✓            |                    |
| TaxCode        | `code`, `name`, `notes`       | `TaxCode.search(q)`   | ✓                  |

Models using [Discard](https://github.com/jhawthorn/discard) only index kept records; discarded records are excluded from multisearch. For model-specific search, use `Model.kept.search(query)` to exclude discarded records, since `pg_search_scope` does not automatically apply the Discard default scope.

## Usage

### Global search (multisearch)

Search across all searchable models at once. Returns `PgSearch::Document` records with a polymorphic `searchable` association.

```ruby
results = PgSearch.multisearch("admin")
results.each do |doc|
  doc.searchable  # => Product, User, etc.
  doc.searchable_type  # => "User", "Product", ...
end

# Chain ActiveRecord methods
PgSearch.multisearch("widget").limit(10)
PgSearch.multisearch("john").where(searchable_type: "User")
```

### Model-specific search

Search within a single model. Returns ActiveRecord objects directly.

```ruby
Product.search("sleeves")
User.search("admin@example.com")
Category.search("beverage")
Supplier.search("acme")
Service.search("consulting")
ProductVariant.search("SKU-001")
TaxCode.search("GST")
```

### Search behavior

- **Prefix search**: Partial words match (e.g. `"prod"` matches `"Product"`).
- **tsearch**: Uses PostgreSQL full-text search by default.
- **pg_trgm**: The trigram extension is enabled for potential future use (fuzzy/typo-tolerant search).

## Index maintenance

### Register lookups

The register uses `Registers::Lookup` against the live product, service, and customer tables. This avoids waiting for asynchronous multisearch indexing after catalog changes.

- `GET /register/lookup?q=...` returns up to 12 compact product/service matches, with exact codes first, followed by word-prefix relevance and sales popularity. Cashiers can choose a result with the arrow keys and Enter or click it; services without codes are supported.
- `GET /customers/search?q=...` uses indexed full-text prefix matching plus indexed customer-name typo matching. Phone numbers are also indexed without punctuation.
- The input debounce is 75 ms. Repeated queries use a per-component memory cache for 30 seconds, capped at 50 entries. Superseded requests are aborted and guarded against late responses. The global palette uses the same behavior, and its cache resets when the signed-in user changes.
- `POST /orders/quick_lookup` accepts JSON and returns the saved cart directly, avoiding the former redirect and register GET. Barcode submissions remain exact-code lookups. Result selections submit a whitelisted type and ID; prices and totals are always read and calculated on the server.
- Scans are queued, show an immediate pending row, and save in order. Other Inertia visits are blocked until pending scans finish. Unconfirmed writes are displayed for review and never automatically retried. The saved cart replaces the Inertia history snapshot and invalidates prefetched pages.
- Register tabs use grouped line counts instead of instantiating lines from every open order. Tax codes and line-discount parents are loaded in bulk, and cart edits reuse the discount calculation state.

Migration `20261022180000` adds concurrent partial indexes for kept records: `(lower(code), id)` on products/services, full-text expression indexes on services/customers, and a customer-name trigram index. The `id` column lets exact barcode lookup retain its first-by-ID ordering without scanning unrelated rows. Apply this migration before deploying the lookup changes. No multisearch rebuild is required.

#### Local performance check

Run `RAILS_ENV=test bin/rails runner script/benchmark_register.rb` after migrating the test database. The script rejects other environments, inserts synthetic data inside a transaction, warms each query three times, measures 20 uncached calls, prints query plans, and rolls back its data. Run it separately from the test suite, which may recreate the test database.

On October 22, 2026, with 20,001 synthetic customers, 20,001 products, and 2,000 services, one local run measured:

| Lookup | Median | p95 |
| --- | ---: | ---: |
| Previous customer query (`Customer.kept.search`) | 137.40 ms | 149.93 ms |
| Indexed customer query | 1.66 ms | 5.14 ms |
| Register product/service search | 2.96 ms | 7.64 ms |
| Exact barcode lookup | 0.55 ms | 2.97 ms |

These are warm local service/query timings for a selective match, excluding HTTP, debounce, browser rendering, and production network latency. Broad prefixes match more rows. Query plans confirmed the customer search indexes and the barcode index were used.

Regression coverage includes query counts for distinct-product carts and unrelated order tabs, real query plans, stale-response/cache behavior (`npm run test:javascript`), rapid scans, keyboard selection, checkout totals, discount removal, and browser history restoration.

### Rebuild after schema or `:against` changes

When you add/remove searchable models, change `:against` columns, or bulk-import data bypassing callbacks:

```bash
bin/rails pg_search:multisearch:rebuild[Product]
bin/rails pg_search:multisearch:rebuild[User]
# ... one per model
```

### Automatic updates

Records are indexed on create/update/destroy via Active Record callbacks. Bulk operations that skip callbacks (e.g. `update_all`, raw SQL) will not update the index; run a rebuild for affected models.

### Temporarily disable indexing

For large bulk imports:

```ruby
PgSearch.disable_multisearch do
  # Bulk create/update operations
end
# Then rebuild: pg_search:multisearch:rebuild[Model]
```

## Adding a new searchable model

1. Include the module and declare search config:

   ```ruby
   class MyModel < ApplicationRecord
     include PgSearch::Model

     multisearchable against: [:name, :other_field], if: :kept?  # if: :kept? for Discard models
     pg_search_scope :search, against: [:name, :other_field], using: { tsearch: { prefix: true } }
   end
   ```

2. Run the rebuild task for the new model.
3. Update this doc (table of searchable models).

## Configuration

- **Multisearch options**: Set `PgSearch.multisearch_options` in an initializer for global defaults (e.g. `using: [:tsearch, :trigram]`, `ignoring: :accents`).
- **Trigram search**: To use `pg_trgm` for fuzzy matching, add `using: { trigram: {} }` or `using: [:tsearch, :trigram]` to `pg_search_scope` / multisearch config. See [pg_search trigram docs](https://github.com/Casecommons/pg_search#trigram-trigram-search).
