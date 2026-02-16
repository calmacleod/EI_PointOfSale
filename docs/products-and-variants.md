# Products

## Overview

Products use a **flat, unified model** where every sellable item is a single `Product` record. This was chosen because the vast majority of inventory (comics, figurines, cards, etc.) are standalone items that don't need variant grouping. For the rare cases where items logically belong together (e.g. clothing sizes), an optional `ProductGroup` provides lightweight grouping.

## Product Model

Each `Product` represents a single sellable item with its own unique barcode/SKU.

| Column | Type | Description |
|--------|------|-------------|
| `code` | string (unique, required) | Barcode or SKU -- the primary lookup key for scanning |
| `name` | string (required) | Display name |
| `selling_price` | decimal(10,2) | Customer-facing price |
| `purchase_price` | decimal(10,2) | Cost price from supplier |
| `stock_level` | integer (default 0) | Current inventory count |
| `reorder_level` | integer (default 0) | Threshold for reorder alerts |
| `order_quantity` | integer | Standard reorder quantity |
| `unit_cost` | decimal(10,2) | Cost per ordering unit |
| `items_per_unit` | integer (default 1) | Items received per ordering unit |
| `supplier_reference` | string | Supplier's catalogue reference |
| `notes` | text | Internal notes |
| `product_url` | string | External product link |
| `metadata` | jsonb (default {}) | Flexible key-value store |
| `discarded_at` | datetime | Soft-delete timestamp (Discard gem) |

### Associations

- `belongs_to :tax_code` (optional) -- tax rate applied at sale
- `belongs_to :supplier` (optional) -- primary supplier
- `belongs_to :added_by` (User, optional) -- who created the record
- `belongs_to :product_group` (optional) -- for Shopify variant grouping
- `has_many_attached :images` -- Active Storage image attachments
- `has_many :categories` -- polymorphic many-to-many via `Categorizable` concern

### Validations

- `name` must be present
- `code` must be present and unique across all products

### Search

Products are indexed in PgSearch for full-text search across `name`, `code`, and `notes`:

```ruby
Product.search("dragon shield")   # fuzzy full-text search
Product.find_by_exact_code("DS-MAT-RED")  # exact barcode lookup (uses unique index)
```

### Soft Delete

Uses the [Discard](https://github.com/jhawthorn/discard) gem:

```ruby
product.discard      # soft-delete
product.undiscard    # restore
Product.kept         # default scope -- only non-deleted
Product.discarded    # only deleted records
```

### Images

Products use Active Storage for image attachments. Multiple images can be attached, and they can be viewed in a lightbox on the product show page.

```ruby
product.images.attach(io: file, filename: "photo.jpg")
product.images.attached?  # => true
```

## Product Groups (Optional Variant Grouping)

`ProductGroup` is a lightweight mechanism for items that should appear as variants of the same product in Shopify. This is entirely optional -- most products have `product_group_id: nil`.

| Column | Type | Description |
|--------|------|-------------|
| `name` | string (required) | Shared product name, e.g. "Primetime Hoodie Ottawa" |
| `shopify_product_id` | string | The shared Shopify product GID |

### When to use a ProductGroup

Use a group when you have multiple items that differ by a single attribute (size, colour) and you want them to appear as variants of one product on your Shopify store. For example:

```ruby
group = ProductGroup.create!(name: "Primetime Hoodie Ottawa")

Product.create!(code: "HOODIE-OTT-S", name: "Small", product_group: group, ...)
Product.create!(code: "HOODIE-OTT-M", name: "Medium", product_group: group, ...)
Product.create!(code: "HOODIE-OTT-L", name: "Large", product_group: group, ...)
```

Each product still has its own barcode, price, and stock level -- the group only controls how they appear together in Shopify.

### When NOT to use a ProductGroup

- Comics, figurines, cards, individual accessories -- anything that is a one-off item
- Items that don't need to be listed together on Shopify
- The majority of your inventory

## Shopify Columns

Products include columns for Shopify synchronisation (see [Shopify Integration docs](shopify-integration.md)):

| Column | Description |
|--------|-------------|
| `shopify_product_id` | Shopify product GID (e.g. `gid://shopify/Product/123`) |
| `shopify_variant_id` | Shopify variant GID |
| `shopify_inventory_item_id` | Shopify inventory item GID for stock sync |
| `sync_to_shopify` | Boolean flag -- set to `true` to include in Shopify sync |
| `shopify_synced_at` | Timestamp of last successful sync |

## Authorization

- **Admins** can create, update, and delete products
- **Common users** can read products (view index, show pages)
- Product management uses `load_and_authorize_resource` with CanCanCan

## File Locations

| Purpose | Path |
|---------|------|
| Model | `app/models/product.rb` |
| ProductGroup model | `app/models/product_group.rb` |
| Controller | `app/controllers/products_controller.rb` |
| Views | `app/views/products/` |
| Fixtures | `test/fixtures/products.yml` |
| Model tests | `test/models/product_test.rb` |
| Controller tests | `test/controllers/products_controller_test.rb` |
| Seed data (Sprig) | `db/seeds/development/products.yml` |
