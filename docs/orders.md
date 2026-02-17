# Orders System

## Overview

The Orders system is the core POS (Point of Sale) module. It handles creating sales, managing line items, processing multiple payment methods, applying discounts, handling tax exemptions, generating receipts, and processing refunds — all backed by an immutable event ledger for auditability.

## Order Lifecycle

```
         ┌─────────┐
         │  Draft   │  ← Created when cashier starts a new order
         └────┬─────┘
              │
         ┌────┴─────┐
    ┌────►│  Held    │  ← Saved for later; any cashier can resume
    │     └────┬─────┘
    │          │ Resume
    │     ┌────▼─────┐
    └─────┤  Draft   │
          └────┬─────┘
               │ Complete (payment validated, stock adjusted)
          ┌────▼──────────┐
          │   Completed   │  ← Frozen — no further edits
          └────┬──────────┘
               │
    ┌──────────┼──────────────┐
    │          │              │
    ▼          ▼              ▼
 Partially   Refunded      Voided
 Refunded                  (admin only)
```

- **Draft**: Order is being built. Lines, payments, discounts, and customer can all be modified.
- **Held**: Saved for later. Appears in the "Held Orders" list. Any cashier can resume it.
- **Completed**: Finalized. Stock is decremented. No modifications allowed except refunds.
- **Voided**: Cancelled by an admin. No stock changes after void.
- **Refunded / Partially Refunded**: One or more refunds processed against the order.

## Immutable Event Ledger

Every mutation to an order is recorded in the `order_events` table. These records are **append-only** — they can never be updated or deleted (enforced at the model level with `before_update` and `before_destroy` guards).

### Event Types

| Event Type              | When it fires                          |
|-------------------------|----------------------------------------|
| `created`               | New order initialized                  |
| `line_added`            | Product/service added to order         |
| `line_removed`          | Line item removed                      |
| `line_quantity_changed` | Quantity updated on a line             |
| `discount_applied`      | Discount added to order                |
| `discount_removed`      | Discount removed                       |
| `customer_assigned`     | Customer linked to order               |
| `customer_removed`      | Customer unlinked                      |
| `payment_added`         | Payment recorded                       |
| `payment_removed`       | Payment removed (draft only)           |
| `held`                  | Order put on hold                      |
| `resumed`               | Order resumed from hold                |
| `completed`             | Order finalized                        |
| `voided`                | Order voided by admin                  |
| `refund_processed`      | Refund created against the order       |

Each event stores:
- `event_type` — one of the above
- `data` — JSONB snapshot of relevant details at the time
- `actor_id` — the user who performed the action
- `created_at` — immutable timestamp

### Why Events?

1. **Audit trail**: See exactly who did what and when, even if the order record itself doesn't show intermediate states.
2. **Dispute resolution**: If a customer disputes a charge, the event log shows every step.
3. **Compliance**: Financial records need a clear trail. Events can't be edited or deleted.

## Price Snapshotting

When a product or service is added to an order, the following data is **copied** (snapshotted) onto the `order_line`:

- `name` — the product/service name at time of sale
- `code` — the product/service code
- `unit_price` — the selling price at time of sale
- `tax_rate` — the effective tax rate
- `tax_code_id` — reference to the tax code used

This means if a product's price changes later, existing completed orders are **not affected**. The receipt always reflects what the customer actually paid.

## Tax Handling

### Product Tax Codes

Each product and service can have an optional `tax_code_id`. When added to an order, the tax code's `rate` determines the tax applied to that line.

### Customer Tax Code Override

Customers can have their own `tax_code_id`. When a customer with a tax code is assigned to an order, **their tax code overrides the product-level tax code** for every line in the order. This is recalculated by `Orders::CalculateTotals` whenever the customer changes.

Use case: A customer with a Status Card (Certificate of Indian Status) has the `EXEMPT_STATUS_INDIAN` tax code assigned, which has a rate of 0%. When they are assigned to an order, all lines become tax-exempt.

### Manual Tax Exempt Toggle

The order also has a `tax_exempt` boolean and `tax_exempt_number` field for manual overrides and record-keeping.

## Discount Model

Discounts can be:

- **Order-wide** (`scope: all_items`): Applies proportionally to all line items
- **Specific items** (`scope: specific_items`): Only applies to linked line items via the `order_discount_items` join table

Each discount has:
- `discount_type`: `percentage` or `fixed_amount`
- `value`: The percentage (e.g., 10 for 10%) or dollar amount
- `calculated_amount`: The actual dollar reduction (computed by `CalculateTotals`)

Discounts are distributed proportionally across line items based on their subtotals.

## Payment Model

Orders support multiple payment methods on a single order:

| Method           | Fields used                          |
|------------------|--------------------------------------|
| Cash             | `amount`, `amount_tendered`, `change_given` |
| Debit            | `amount`, `reference`                |
| Credit           | `amount`, `reference`                |
| Store Credit     | `amount`, `reference`                |
| Gift Certificate | `amount`, `reference`                |
| Other            | `amount`, `reference`                |

### Cash Change Calculation

For cash payments, the cashier enters the `amount_tendered` (how much the customer handed over). The system calculates `change_given = amount_tendered - amount`. Both values are persisted for the receipt and audit trail.

### Payment Validation

An order cannot be completed unless `sum(payments.amount) >= order.total`. The UI disables the "Complete" button until this condition is met.

## Stock Adjustment

When an order is **completed**, `Orders::Complete` decrements the `stock_level` of each product in the order:

```ruby
product.stock_level -= order_line.quantity
```

- Stock can go **negative** (the business wants to know they oversold).
- Services do not have stock and are skipped.
- Stock is **not** adjusted for held or draft orders.

When a refund is processed with `restock: true`, stock is incremented back:

```ruby
product.stock_level += refund_line.quantity
```

## Receipt Generation

`Orders::GenerateReceipt` uses the active `ReceiptTemplate` to format a thermal-printer-style receipt. It outputs an array of fixed-width text lines that include:

1. Store header (name, address, phone)
2. Order number, date, cashier name
3. Customer name (if assigned)
4. Line items with quantity, price, and totals
5. Discounts
6. Subtotal, tax, total
7. Payment methods with amounts
8. Cash tendered and change (for cash payments)
9. Tax exempt notice (if applicable)
10. Footer text from template

The receipt preview renders in a monospace font card on the order show page.

## Service Objects

| Service                    | Purpose                                                      |
|----------------------------|--------------------------------------------------------------|
| `Orders::CalculateTotals`  | Recomputes all money fields from lines and discounts         |
| `Orders::RecordEvent`      | Appends an immutable event to the audit log                  |
| `Orders::Complete`         | Validates payment, adjusts stock, freezes the order          |
| `Orders::Hold`             | Moves a draft order to held status                           |
| `Orders::Resume`           | Moves a held order back to draft                             |
| `Orders::ProcessRefund`    | Creates refund records, optionally restocks, updates status  |
| `Orders::GenerateReceipt`  | Formats a receipt using the active ReceiptTemplate           |

## Store-Wide Orders

Orders are **not scoped to individual users**. Any authenticated cashier can:
- See all draft and held orders in the tab bar
- Resume and work on any held order
- View completed order history

The `created_by_id` field tracks who started the order, and `order_events.actor_id` records who performed each action. This provides full traceability without restricting access.

## Authorization

| Action                  | Who can do it        |
|-------------------------|----------------------|
| Create, edit, complete  | All authenticated users |
| Hold, resume            | All authenticated users |
| View order history      | All authenticated users |
| Void orders             | Admin only           |
| Process refunds         | Admin only           |
| View event audit trail  | Admin only           |
