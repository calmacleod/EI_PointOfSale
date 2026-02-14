# Products and Variants

## Overview

The product model uses a **parent + variant** structure. Every sellable physical item is a `ProductVariant`; `Product` is the parent that groups variants together.

## Product vs ProductVariant

| | Product | ProductVariant |
|---|---|---|
| **Purpose** | Parent/grouping (e.g. "Dragon Shield Matte Sleeves") | Sellable SKU with code, price, stock |
| **Code (SKU)** | — | Unique per variant |
| **Price** | — | Per variant |
| **Stock** | — | Per variant |
| **Supplier** | Default supplier | Optional override |

## Simple vs Multi-Variant Products

- **Simple products**: One Product with one ProductVariant (e.g. NHL Team Puck).
- **Multi-variant products**: One Product with many ProductVariants (e.g. card sleeves in Red, Blue, Green, Black).

Variants store option attributes in `option_values` (JSONB), e.g. `{ "color": "Red" }`.

## Relationships

- **Product** → `tax_code`, `supplier`, `added_by` (User)
- **ProductVariant** → `product`, optional `supplier` override
- **Product** includes **Categorizable** → many-to-many with `Category` via polymorphic `categorizations`

## Soft Delete

Both models use the [Discard](https://github.com/jhawthorn/discard) gem:

- `record.discard` / `record.undiscard`
- Default scope: `Model.kept` (excludes discarded)
- `Model.discarded` scope for discarded records

## Images

Use **Active Storage** on Product or ProductVariant. There is no `image_path` column.
