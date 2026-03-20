# Shopify Integration

## Overview

The app integrates with Shopify to synchronise products and inventory between the in-store POS system and an online Shopify storefront. The integration uses Shopify's Admin GraphQL API via the `shopify_api` gem (v16+) and is designed for a **custom app** created through the Shopify Dev Dashboard.

Key capabilities:

- **Push products to Shopify** -- create or update products in your Shopify store
- **Pull products from Shopify** -- import existing Shopify products as local Product records
- **Sync inventory levels** -- keep stock counts in sync between POS and Shopify
- **Handle webhooks** -- automatically adjust local stock when a Shopify order is placed

## Setup

### 1. Create a Shopify App via the Dev Dashboard

> **Note:** As of January 2026, Shopify no longer allows creating new custom apps directly in the Shopify admin. All new apps must be created through the Dev Dashboard.

1. Go to the **Shopify Dev Dashboard** at [partners.shopify.com](https://partners.shopify.com/)
2. Click **Create app** and name it (e.g. "EI POS Integration")
3. Under **Configuration > API access**, set the required **Admin API scopes**:
   - `read_products`
   - `write_products`
   - `read_inventory`
   - `write_inventory`
   - `read_orders`
4. Click **Install app** on your store
5. Copy the **Client ID** and **Client secret** from the app's overview page

### 2. Store Credentials

Open Rails encrypted credentials:

```bash
bin/rails credentials:edit
```

Add the following block:

```yaml
shopify:
  shop_domain: "yourstore.myshopify.com"
  client_id: "your-client-id"
  client_secret: "your-client-secret"
  api_version: "2026-01"
```

### 3. Verify Connection

After configuring credentials, restart the Rails server and visit **Admin > Settings > Shopify**. Click **Test connection** to verify the API credentials are working.

## Authentication

The integration uses the **Client Credentials Grant** to obtain access tokens from Shopify. This replaces the older static access token (`shpat_`) approach.

- Tokens are obtained by POSTing `client_id` and `client_secret` to the store's `/admin/oauth/access_token` endpoint with `grant_type=client_credentials`.
- Tokens expire after **24 hours**.
- The app caches tokens for 23 hours via `Rails.cache` to avoid unnecessary token requests.
- Token fetching is handled transparently by `ShopifySync::Base`.

## Architecture

### Service Objects

All Shopify communication lives in `app/services/shopify_sync/`:

| Service | Purpose |
|---------|---------|
| `ShopifySync::Base` | Base class providing session management, token fetching, and GraphQL client helpers |
| `ShopifySync::ProductPusher` | Pushes a product (or product group) to Shopify. Creates or updates. |
| `ShopifySync::ProductPuller` | Pulls all products from Shopify into local database |
| `ShopifySync::InventorySyncer` | Synchronises stock levels for all (or one) synced product(s) |
| `ShopifySync::WebhookHandler` | Processes incoming Shopify webhook payloads |

### Background Jobs

All jobs live in `app/jobs/shopify_sync/` and run via Solid Queue:

| Job | Purpose |
|-----|---------|
| `ShopifySync::PushProductJob` | Pushes a single product to Shopify (enqueued on save when `sync_to_shopify` is true) |
| `ShopifySync::SyncInventoryJob` | Syncs inventory levels for all or one product |
| `ShopifySync::ProcessWebhookJob` | Processes a webhook payload asynchronously |

### Initializer

`config/initializers/shopify.rb` sets up `ShopifyAPI::Context` at boot time using `client_id` and `client_secret` from Rails credentials. If credentials are missing, the integration gracefully stays dormant.

## How Sync Works

### Standalone Products (no group)

Most products sync as a 1:1 mapping -- one local `Product` becomes one Shopify product with one variant:

```
Local Product (code: "ASM-001")
  -> Shopify Product (title: "Amazing Spider-Man #1")
       -> Shopify Variant (sku: "ASM-001", price: 12.99)
```

The Shopify GIDs are stored back on the local record:

- `shopify_product_id` -- the Shopify product's global ID
- `shopify_variant_id` -- the Shopify variant's global ID
- `shopify_inventory_item_id` -- for inventory level sync

### Grouped Products (with ProductGroup)

Products that share a `ProductGroup` are pushed as variants of a single Shopify product:

```
ProductGroup (name: "Primetime Hoodie Ottawa")
  -> Shopify Product (title: "Primetime Hoodie Ottawa")
       -> Variant 1 (sku: "HOODIE-OTT-S", name: "Small")
       -> Variant 2 (sku: "HOODIE-OTT-M", name: "Medium")
       -> Variant 3 (sku: "HOODIE-OTT-L", name: "Large")
```

The group's `shopify_product_id` is the shared Shopify product GID. Each local product still stores its own `shopify_variant_id`.

### Inventory Sync

`ShopifySync::InventorySyncer` uses the Shopify `inventorySetQuantities` mutation to push local stock levels to Shopify. It queries the first Shopify location (your primary store location) and sets the "available" quantity.

To sync a single product:

```ruby
ShopifySync::SyncInventoryJob.perform_later(product.id)
```

To sync all flagged products:

```ruby
ShopifySync::SyncInventoryJob.perform_later
```

### Webhooks

`ShopifySync::WebhookHandler` processes two webhook topics:

#### `orders/create`

When a customer places a Shopify order (e.g. in-store pickup), the handler matches each line item's `variant_id` to a local product via `shopify_variant_id` and decrements the local `stock_level`. Stock will not go below zero.

#### `products/update`

When a product is updated in Shopify, the handler updates the local `selling_price` and `shopify_synced_at` for any matching products.

## Flagging Products for Sync

Individual products are flagged for Shopify sync using the **"Sync to Shopify"** checkbox on the product edit form. Only products with `sync_to_shopify: true` are included in push and inventory sync operations.

```ruby
product.update!(sync_to_shopify: true)
```

## Admin UI

The Shopify admin page is at **Admin > Settings > Shopify** (`/admin/shopify`). It provides:

- **Connection status** -- whether credentials are configured, with a test button
- **Setup instructions** -- step-by-step guide displayed when not yet configured
- **Sync status** -- count of products flagged for sync, last sync timestamp
- **Sync all button** -- enqueues push jobs for all flagged products plus an inventory sync

## File Locations

| Purpose | Path |
|---------|------|
| Initializer | `config/initializers/shopify.rb` |
| Base service | `app/services/shopify_sync/base.rb` |
| Product pusher | `app/services/shopify_sync/product_pusher.rb` |
| Product puller | `app/services/shopify_sync/product_puller.rb` |
| Inventory syncer | `app/services/shopify_sync/inventory_syncer.rb` |
| Webhook handler | `app/services/shopify_sync/webhook_handler.rb` |
| Push job | `app/jobs/shopify_sync/push_product_job.rb` |
| Inventory job | `app/jobs/shopify_sync/sync_inventory_job.rb` |
| Webhook job | `app/jobs/shopify_sync/process_webhook_job.rb` |
| Admin controller | `app/controllers/admin_area/shopify_controller.rb` |
| Admin view | `app/views/admin_area/shopify/show.html.erb` |
| Tests | `test/services/shopify_sync/`, `test/jobs/shopify_sync/`, `test/controllers/admin_area/shopify_controller_test.rb` |
