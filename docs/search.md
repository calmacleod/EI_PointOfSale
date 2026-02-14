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
