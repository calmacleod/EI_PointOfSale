# Services

## Overview

Services are sellable items with **no inventory**. Examples: printer cartridge refills, card sleeving.

## Schema

- `name`, `code` (optional internal ref, e.g. SVC-REFILL-SM)
- `description`, `price`
- `tax_code`, `added_by` (User)
- `metadata` (JSONB)
- No supplier, stock, or variants

## Categories

Service includes **Categorizable** and can be assigned to categories (e.g. "Services") via the polymorphic `categorizations` join table.

## Future Order Integration

Order line items will use a polymorphic `line_itemable`:

- `line_itemable_type` + `line_itemable_id` → `ProductVariant` or `Service`
- Both can be added to the same order

## Service Tiers

Different tiers (e.g. small vs large refill) are modeled as separate Service records, not variants.
