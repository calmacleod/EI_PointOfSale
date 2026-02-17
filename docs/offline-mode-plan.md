# Offline Register Mode — Implementation Plan

> **Status**: Planning (not yet started)
> **Created**: 2026-02-17
> **Goal**: Allow the POS register to continue processing sales when the server is unavailable, then sync completed orders when connectivity is restored.

---

## Table of Contents

1. [Problem Statement](#1-problem-statement)
2. [Architecture Overview](#2-architecture-overview)
3. [Phase 1 — IndexedDB Catalog Cache](#phase-1--indexeddb-catalog-cache)
4. [Phase 2 — Connectivity Detection & Offline UI](#phase-2--connectivity-detection--offline-ui)
5. [Phase 3 — Client-Side Order Engine](#phase-3--client-side-order-engine)
6. [Phase 4 — Background Sync](#phase-4--background-sync)
7. [Phase 5 — Hardening & Edge Cases](#phase-5--hardening--edge-cases)
8. [Data Model Reference](#data-model-reference)
9. [Business Logic to Replicate in JS](#business-logic-to-replicate-in-js)
10. [Open Questions](#open-questions)

---

## 1. Problem Statement

This app is used in a retail setting. If the web server goes down (crash, network outage, power to server room, etc.), the register cannot process any sales. This is unacceptable for a production POS system — a store needs to keep selling even if the back office is offline.

### Constraints

- The register is a Rails-rendered PWA using Turbo Streams and Stimulus controllers
- We are **not** rewriting the register in a SPA framework — the offline mode is an enhancement layer
- Online mode should work exactly as it does today (zero degradation)
- Offline orders must eventually sync back to the server with full fidelity

### Storage Budget

| Data          | Records  | Estimated Size |
|---------------|----------|---------------|
| Products      | ~100,000 | ~9 MB         |
| Customers     | ~5,000   | ~600 KB       |
| Tax Codes     | ~20      | ~1 KB         |
| **Total**     |          | **~10 MB**    |

IndexedDB limits: Chrome allows up to 60% of disk space. 10 MB is trivial.

---

## 2. Architecture Overview

```
┌─────────────────────────────────────────────────────────┐
│                     Register UI                         │
│              (existing ERB + Stimulus)                   │
├──────────────────────┬──────────────────────────────────┤
│    Online Path       │       Offline Path               │
│                      │                                  │
│  Turbo Stream POST ──┤── offline_register_controller.js │
│  Server renders HTML │   Reads from IndexedDB           │
│  Server updates DB   │   Renders DOM directly           │
│                      │   Queues order in IndexedDB      │
├──────────────────────┴──────────────────────────────────┤
│                  Connection Monitor                      │
│          (detects online/offline transitions)            │
├─────────────────────────────────────────────────────────┤
│                   Service Worker                         │
│         (intercepts requests when offline,               │
│          triggers background sync on reconnect)          │
├─────────────────────────────────────────────────────────┤
│                     IndexedDB                            │
│   ┌──────────┐  ┌───────────┐  ┌─────────────────┐     │
│   │ products │  │ customers │  │ offline_orders   │     │
│   │ services │  │ tax_codes │  │ pending_sync     │     │
│   └──────────┘  └───────────┘  └─────────────────┘     │
└─────────────────────────────────────────────────────────┘
```

### Key Principle: Two Code Paths, One UI

- **Online**: Everything works as today. Turbo Streams handle rendering. Server is the source of truth.
- **Offline**: Stimulus controller intercepts form submissions, performs calculations locally, updates the DOM directly, and queues the completed order for later sync.

The user sees the same register interface in both modes, with an indicator showing current connectivity status.

---

## Phase 1 — IndexedDB Catalog Cache

**Goal**: Populate and maintain a local copy of product, service, customer, and tax code data in the browser.

### 1.1 Add Dexie.js

[Dexie.js](https://dexie.org/) is a lightweight (~45 KB) IndexedDB wrapper with a clean API and good indexing support.

```bash
bin/importmap pin dexie
```

If Dexie isn't available via CDN for importmap, vendor it into `vendor/javascript/dexie.js`.

### 1.2 Define the IndexedDB Schema

Create `app/javascript/lib/offline_db.js`:

```javascript
import Dexie from "dexie"

const db = new Dexie("ei_pos_offline")

db.version(1).stores({
  products:       "id, code, name, updated_at",
  services:       "id, code, name, updated_at",
  tax_codes:      "id, code",
  customers:      "id, name, member_number, phone, updated_at",
  offline_orders: "id, status, created_at",
  sync_queue:     "++id, order_id, created_at",
  meta:           "key"  // stores last_synced_at, device_id, etc.
})

export default db
```

### 1.3 Server-Side Catalog Endpoint

Create `app/controllers/api/catalog_controller.rb`:

```ruby
module Api
  class CatalogController < ApplicationController
    # GET /api/catalog.json?since=2026-02-17T00:00:00Z
    def show
      since = params[:since] ? Time.zone.parse(params[:since]) : Time.at(0)

      render json: {
        products: products_since(since),
        services: services_since(since),
        tax_codes: tax_codes_since(since),
        customers: customers_since(since),
        synced_at: Time.current.iso8601
      }
    end

    private

    def products_since(since)
      Product.where("updated_at > ?", since)
             .select(:id, :code, :name, :selling_price, :stock_level,
                     :tax_code_id, :discarded_at, :updated_at)
    end

    def services_since(since)
      Service.where("updated_at > ?", since)
             .select(:id, :code, :name, :price, :tax_code_id,
                     :discarded_at, :updated_at)
    end

    def tax_codes_since(since)
      TaxCode.where("updated_at > ?", since)
             .select(:id, :code, :name, :rate, :exemption_type,
                     :province_code, :discarded_at)
    end

    def customers_since(since)
      Customer.where("updated_at > ?", since)
              .select(:id, :name, :member_number, :phone, :email,
                      :tax_code_id, :status_card_number, :alert,
                      :active, :discarded_at, :updated_at)
    end
  end
end
```

**Important**: The first sync (no `since` param) will return all ~105,000 records. Consider streaming with `response.stream` or paginating if this causes timeout issues. Subsequent delta syncs will be tiny.

### 1.4 Catalog Sync Stimulus Controller

Create `app/javascript/controllers/catalog_sync_controller.js`:

- Runs on the register page (attached to `<body>` or the register container)
- On `connect()`: checks `meta.last_synced_at` in IndexedDB, fetches delta from `/api/catalog.json?since=...`
- Bulk upserts records into IndexedDB using `db.products.bulkPut()`
- Stores new `synced_at` timestamp in `meta` table
- Runs on a timer (e.g., every 5 minutes while online)
- Shows a subtle sync indicator (spinning icon, last synced time)

### 1.5 Initial Sync Strategy

For the first-ever sync with ~100K products:

- The server should respond with newline-delimited JSON (NDJSON) or chunked JSON
- The client processes records in batches (e.g., 1,000 at a time) to avoid blocking the UI
- Show a progress bar: "Syncing catalog... 45,000 / 100,000 products"
- This only happens once per device; subsequent syncs are delta-only

---

## Phase 2 — Connectivity Detection & Offline UI

**Goal**: Detect when the server is unreachable and provide clear visual feedback.

### 2.1 Connection Monitor

Create `app/javascript/lib/connection_monitor.js`:

```javascript
class ConnectionMonitor {
  constructor() {
    this.online = navigator.onLine
    this.callbacks = new Set()

    window.addEventListener("online", () => this.update(true))
    window.addEventListener("offline", () => this.update(false))

    // Heartbeat: ping the server every 30s to catch cases where
    // navigator.onLine is true but the server is actually unreachable
    this.startHeartbeat()
  }

  startHeartbeat() {
    setInterval(async () => {
      try {
        const res = await fetch("/api/health", {
          method: "HEAD",
          cache: "no-store"
        })
        this.update(res.ok)
      } catch {
        this.update(false)
      }
    }, 30_000)
  }

  update(online) {
    if (this.online !== online) {
      this.online = online
      this.callbacks.forEach(cb => cb(online))
    }
  }

  onChange(callback) {
    this.callbacks.add(callback)
    return () => this.callbacks.delete(callback)
  }
}

export default new ConnectionMonitor()
```

**Important**: `navigator.onLine` only detects network interface status, not actual server reachability. The heartbeat is essential.

### 2.2 Health Check Endpoint

Add `Api::HealthController#show` returning a simple 200 OK. Keep it as lightweight as possible (no DB queries, no auth).

### 2.3 Offline UI Indicators

Add to the register layout:

- **Status badge** in the tab bar area: green dot = online, red dot = offline
- **"Offline Mode" banner** across the top when offline (dismissable but persistent)
- **"X orders pending sync"** badge near the status indicator
- **Pulse/glow animation** when transitioning between states so it's noticeable

### 2.4 Service Worker Updates

Update `app/views/pwa/service-worker.js` to:

- **Precache the register page** (`/register`) on install, so navigating to it works offline
- **Cache API responses** for catalog data with a network-first strategy
- **Let non-GET requests through** when online, intercept when offline (Phase 3)

---

## Phase 3 — Client-Side Order Engine

**Goal**: When offline, handle the full order lifecycle in JavaScript using IndexedDB-cached data.

This is the core of the offline capability and the most complex phase.

### 3.1 Offline Order Data Model

Orders stored in IndexedDB `offline_orders` table:

```javascript
{
  id: "OFF-REG1-00042",          // offline order ID (see numbering below)
  status: "draft",                // draft | held | completed
  customer_id: null,              // references customers table in IDB
  customer_name: null,
  customer_tax_code_id: null,
  lines: [
    {
      id: crypto.randomUUID(),
      sellable_type: "Product",
      sellable_id: 12345,
      code: "ABC-1234",
      name: "Widget Blue 10pk",
      unit_price: 29.99,
      quantity: 2,
      tax_code_id: 1,
      tax_rate: 0.13,
      discount_amount: 0,
      tax_amount: 7.80,           // calculated
      line_total: 67.78           // calculated
    }
  ],
  discounts: [
    {
      id: crypto.randomUUID(),
      discount_type: "percentage", // percentage | fixed
      scope: "all_items",          // all_items | specific_items
      value: 10,
      calculated_amount: 6.00,
      line_ids: []                 // only for specific_items scope
    }
  ],
  payments: [
    {
      id: crypto.randomUUID(),
      method: "cash",
      amount: 67.78,
      amount_tendered: 70.00,
      change: 2.22,
      reference: null
    }
  ],
  subtotal: 59.98,
  discount_total: 6.00,
  tax_total: 7.02,
  total: 61.00,
  notes: "",
  created_at: "2026-02-17T14:30:00Z",
  completed_at: null,
  held_at: null,
  created_by_id: 5,
  device_id: "REG1",
  synced: false
}
```

### 3.2 Order Number Strategy

- **Device ID**: Set during initial setup (stored in `meta` table). Could be a register name like `REG1` or a short random ID.
- **Offline sequence**: Auto-incrementing per device, stored in `meta.offline_sequence`
- **Format**: `OFF-{device_id}-{sequence}` (e.g., `OFF-REG1-00042`)
- **On sync**: The server assigns a real `ORD-XXXXXX` number. The offline ID is preserved in a `offline_reference` field for auditing.

### 3.3 Client-Side Calculation Engine

Create `app/javascript/lib/order_calculator.js`:

This replicates `Orders::CalculateTotals` in JavaScript. The Ruby logic is straightforward enough to port directly:

```javascript
export function calculateOrderTotals(order) {
  const customerTaxCodeId = order.customer_tax_code_id

  // 1. Recalculate line taxes (customer tax code overrides product tax code)
  for (const line of order.lines) {
    if (customerTaxCodeId) {
      // Look up customer's tax code rate from cached tax_codes
      const taxCode = await db.tax_codes.get(customerTaxCodeId)
      line.tax_rate = taxCode?.rate ?? 0
      line.tax_code_id = customerTaxCodeId
    }
    line.tax_amount = round2(line.taxableAmount * line.tax_rate)
    line.line_total = line.taxableAmount + line.tax_amount
  }

  // 2. Apply discounts
  for (const discount of order.discounts) {
    const applicableLines = discount.scope === "all_items"
      ? order.lines
      : order.lines.filter(l => discount.line_ids.includes(l.id))

    const subtotal = applicableLines.reduce((s, l) => s + subtotalBeforeDiscount(l), 0)

    discount.calculated_amount = discount.discount_type === "percentage"
      ? round2(subtotal * (discount.value / 100))
      : round2(Math.min(discount.value, subtotal))
  }

  // 3. Distribute discounts proportionally across lines
  distributeDiscountsToLines(order)

  // 4. Update order totals
  order.subtotal = round2(order.lines.reduce((s, l) => s + subtotalBeforeDiscount(l), 0))
  order.discount_total = round2(order.discounts.reduce((s, d) => s + d.calculated_amount, 0))
  order.tax_total = round2(order.lines.reduce((s, l) => s + l.tax_amount, 0))
  order.total = round2(order.subtotal - order.discount_total + order.tax_total)
}

function subtotalBeforeDiscount(line) {
  return (line.unit_price ?? 0) * (line.quantity ?? 0)
}

function round2(n) {
  return Math.round(n * 100) / 100
}

// Canadian cash rounding (nearest 5 cents)
export function cashRound(amount) {
  return Math.round(amount * 20) / 20
}
```

### 3.4 Offline Register Stimulus Controller

Create `app/javascript/controllers/offline_register_controller.js`:

This is the main orchestrator. It:

1. **Intercepts form submissions** when offline:
   - Code lookup form → searches IndexedDB instead of POSTing to `/orders/:id/quick_lookup`
   - Payment form → stores payment locally instead of POSTing to `/order_payments`
   - Quantity updates → updates local order instead of PATCHing
   - Complete button → validates and marks order as completed locally

2. **Renders DOM updates** that normally come from Turbo Streams:
   - Has template functions for each replaceable fragment:
     - `renderLineItems(order)` → replaces `#order_line_items`
     - `renderTotals(order)` → replaces `#order_totals`
     - `renderPaymentsPanel(order)` → replaces `#order_payments_panel`
     - `renderCustomerPanel(order)` → replaces `#order_customer_panel`
     - `renderActionButtons(order)` → replaces `#order_action_buttons`
   - These render simplified versions of the existing partials (no server-only features like auditing links)

3. **Manages offline order lifecycle**:
   - Create new draft → generates offline order ID, stores in IndexedDB
   - Add line item → snapshot from cached product/service, recalculate totals
   - Remove line item → remove and recalculate
   - Update quantity → update and recalculate
   - Add/remove discount → recalculate
   - Assign customer → update tax codes on all lines, recalculate
   - Add payment → validate, calculate change for cash
   - Complete order → validate (has lines, payment complete), mark completed
   - Hold/resume → toggle status

4. **Interop with existing controllers**:
   - `product_search_controller.js` needs to search IndexedDB when offline instead of fetching `/search.json`
   - `customer_search_controller.js` needs a similar offline path
   - `payment_form_controller.js` cash rounding already works client-side

### 3.5 Product/Customer Search — Offline Mode

Modify `product_search_controller.js`:

```javascript
async search() {
  if (connectionMonitor.online) {
    // existing fetch to /search.json
  } else {
    const query = this.inputTarget.value.toLowerCase()
    const results = await db.products
      .where("code").equals(query)
      .or("name").startsWithIgnoreCase(query)
      .limit(20)
      .toArray()
    this.renderResults(results)
  }
}
```

Dexie supports compound indexes and `WhereClause` for efficient querying even with 100K records.

For customer search, a similar pattern against the `customers` table.

### 3.6 Receipt Printing — Offline

If the store prints receipts (thermal printer), the receipt data needs to come from the local order data. This may require:

- Caching the store info (name, address, phone) in `meta`
- A simplified receipt template rendered in JS
- Or: queue receipt printing for when connectivity returns (less ideal for retail)

---

## Phase 4 — Background Sync

**Goal**: When connectivity returns, replay offline orders to the server.

### 4.1 Sync Endpoint

Create `Api::OrderSyncController`:

```ruby
module Api
  class OrderSyncController < ApplicationController
    # POST /api/orders/sync
    # Accepts an array of offline orders and creates real orders
    def create
      results = params[:orders].map do |offline_order|
        Orders::SyncOffline.call(
          payload: offline_order,
          actor: Current.user
        )
      end

      render json: {
        synced: results.select(&:success?).map { |r|
          { offline_id: r.offline_id, order_id: r.order.id, number: r.order.number }
        },
        failed: results.reject(&:success?).map { |r|
          { offline_id: r.offline_id, errors: r.errors }
        }
      }
    end
  end
end
```

### 4.2 Server-Side Sync Service

Create `app/services/orders/sync_offline.rb`:

This service:

1. Creates a real `Order` from the offline payload
2. Creates `OrderLine` records with proper `sellable` associations (looks up by `sellable_type` + `sellable_id`)
3. Creates `OrderPayment` records
4. Creates `OrderDiscount` records
5. Runs `Orders::CalculateTotals` to verify the server-calculated totals match the offline totals (flag discrepancies but don't reject)
6. If the order was completed offline, calls `Orders::Complete` (skipping the stock adjustment if stock is now insufficient — flag for review instead)
7. Stores the `offline_reference` (e.g., `OFF-REG1-00042`) on the order for audit trail
8. Links to the appropriate `CashDrawerSession` if one was active

### 4.3 Service Worker Sync Handler

Update the service worker to use the [Background Sync API](https://developer.mozilla.org/en-US/docs/Web/API/Background_Synchronization_API):

```javascript
self.addEventListener("sync", (event) => {
  if (event.tag === "sync-offline-orders") {
    event.waitUntil(syncOfflineOrders())
  }
})

async function syncOfflineOrders() {
  // Read pending orders from IndexedDB
  // POST to /api/orders/sync
  // On success: mark orders as synced, update with real order numbers
  // On failure: leave in queue for next sync attempt
}
```

### 4.4 Client-Side Sync Manager

Create `app/javascript/lib/sync_manager.js`:

- Triggered when `ConnectionMonitor` detects the server is reachable again
- Reads all orders from `offline_orders` where `synced === false`
- Sends them to `/api/orders/sync` in batches
- Updates local records with server-assigned order numbers
- Handles partial failures (some orders sync, others don't)
- Shows progress: "Syncing 3 orders... 2/3 complete"
- Registers a Background Sync event as a fallback (in case the page is closed before sync completes)

### 4.5 CSRF Token Handling

Offline-created requests will have stale CSRF tokens. Solutions:

- The sync endpoint uses API token auth (a device token stored in `meta`) instead of session + CSRF
- Or: fetch a fresh CSRF token as the first step of sync (GET any page, extract from meta tag)

### 4.6 Conflict Resolution Strategy

| Conflict | Resolution |
|----------|-----------|
| Product price changed since offline | Use the snapshotted price (it was the price at time of sale) — this is correct behavior |
| Product was deleted/discarded | Sync succeeds (snapshot has all needed data), flag for review |
| Stock went negative after sync | Allow it, flag for review (the sale already happened in reality) |
| Customer was deactivated | Sync succeeds, flag for review |
| Duplicate offline ID | Reject (idempotency — order was already synced) |

The philosophy: **the sale already happened in the real world**. The sync's job is to record it, not to re-validate it. Flag anomalies for manager review but don't reject orders.

---

## Phase 5 — Hardening & Edge Cases

### 5.1 Multi-Register Conflicts

If multiple registers are offline simultaneously:

- Each register has a unique `device_id` so order numbers don't collide
- Stock levels may go negative after sync (two registers both sell the last item) — flag for review
- The sync endpoint is idempotent on `offline_reference` to prevent double-syncing

### 5.2 Long Offline Periods

If the server is down for hours/days:

- The catalog cache gets stale (prices may have changed, new products added)
- Show "Catalog last synced X hours ago" warning
- Products not in the cache can't be sold — show a clear error ("Product not found in offline catalog")
- Consider a "manual entry" mode for items not in the cache (code, name, price entered manually)

### 5.3 Authentication During Offline

- The user must have already been authenticated (session cookie exists) before going offline
- Store the current user's ID and name in `meta` when the register page loads
- Offline orders are attributed to this user
- If the session expires during a long offline period, sync will need to re-authenticate first

### 5.4 Cash Drawer Session

- Store the current `CashDrawerSession` ID in `meta` when the register loads
- Offline orders reference this session ID
- If the session was closed/reconciled before sync, the sync service links them to the most recent session or flags for review

### 5.5 Testing Strategy

- **Unit tests** for `order_calculator.js` — port the Ruby calculation test cases to JS
- **Integration tests** using a service worker mock — simulate offline, create orders, verify sync
- **Server-side tests** for `Orders::SyncOffline` — test all conflict scenarios
- **Manual QA**: physically disconnect from the network, process sales, reconnect, verify

### 5.6 Data Cleanup

- Synced offline orders can be purged from IndexedDB after 30 days
- Catalog data is continuously refreshed; no cleanup needed
- `meta` table entries are permanent

---

## Data Model Reference

### Fields Needed Per Table (Offline Cache)

**Products** (indexed on `id`, `code`, `name`):
```
id, code, name, selling_price, stock_level, tax_code_id, discarded_at, updated_at
```

**Services** (indexed on `id`, `code`, `name`):
```
id, code, name, price, tax_code_id, discarded_at, updated_at
```

**Tax Codes** (indexed on `id`, `code`):
```
id, code, name, rate, exemption_type, province_code, discarded_at
```

**Customers** (indexed on `id`, `name`, `member_number`, `phone`):
```
id, name, member_number, phone, email, tax_code_id, status_card_number, alert, active, discarded_at, updated_at
```

---

## Business Logic to Replicate in JS

All of this logic exists in Ruby today and must be faithfully ported to JavaScript for offline use.

### Line Total Calculation
Source: `OrderLine#calculate_line_total` (`app/models/order_line.rb:43-46`)

```
subtotal_before_discount = unit_price * quantity
taxable_amount = subtotal_before_discount - discount_amount
tax_amount = round2(taxable_amount * tax_rate)
line_total = taxable_amount + tax_amount
```

### Order Totals
Source: `Orders::CalculateTotals` (`app/services/orders/calculate_totals.rb`)

```
subtotal      = sum of all lines' subtotal_before_discount
discount_total = sum of all discounts' calculated_amount
tax_total     = sum of all lines' tax_amount
total         = subtotal - discount_total + tax_total
```

### Discount Distribution
Source: `Orders::CalculateTotals#distribute_discounts_to_lines` (`:68-90`)

Discounts are distributed proportionally across lines based on each line's share of the subtotal. The last line absorbs any rounding remainder.

### Canadian Cash Rounding
Source: `payment_form_controller.js` (already client-side)

```
rounded = Math.round(amount * 20) / 20
```

### Payment Completeness
Source: `Order#payment_complete?`

```
total - amount_paid < 0.03
```

### Customer Tax Code Override
Source: `Orders::CalculateTotals#recalculate_line_taxes` (`:28-41`)

When a customer with a `tax_code` is assigned, their tax code overrides the product/service-level tax code on every line.

---

## Open Questions

1. **Receipt printing offline**: Do we need offline receipt printing, or can receipts wait for sync? If needed, what printer hardware/protocol is used? (ESC/POS over USB? Network printer?)

2. **Device registration**: How should registers get their `device_id`? Manual setup? Auto-generated on first use?

3. **Initial sync UX**: Should the first catalog sync (100K products) happen during a setup wizard, or lazily when the register is first opened?

4. **Manual entry fallback**: Should cashiers be able to manually enter product code/name/price for items not in the offline cache?

5. **Multiple draft orders offline**: Should the offline mode support the same multi-tab draft workflow as online, or simplify to one order at a time?

6. **Held orders**: Should offline-created orders be hold-able, or should hold/resume be online-only? (Held orders are less critical than completing sales.)

7. **Discounts offline**: Should the full discount system work offline, or should discounts be limited/disabled in offline mode to reduce complexity?

8. **Sync authentication**: Should we use a device token (simpler) or require the user to re-authenticate before sync (more secure)?
