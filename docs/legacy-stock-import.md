# Legacy STOCK Import

## Source

EI_PLACE_2022 Access database, exported to PostgreSQL. The `Stock` table structure:

| STOCK Column | Type | Example |
|--------------|------|---------|
| Stock_Code | TEXT | 880025 |
| Product_Name | TEXT | Brat Player Boston |
| Selling_Price | DOUBLE PRECISION | 7.99 |
| Purchase_Price | DOUBLE PRECISION | 3.95 |
| Stock_Level | DOUBLE PRECISION | 0 |
| Tax_Applied | TEXT | 2 |
| Date_Added | TIMESTAMP | 2007-03-29 |
| Added_By | TEXT | (empty) |
| Stock_Cat | TEXT | NHL Novelties |
| Reorder_Level | DOUBLE PRECISION | 0 |
| Supplier | TEXT | JF Sports |
| Supp_Phone | TEXT | 1-800-267-0513 |
| Order2_Level | DOUBLE PRECISION | 4 |
| OUnit_Cost | DOUBLE PRECISION | 3.95 |
| Items_Unit | DOUBLE PRECISION | 1 |
| Supp_Ref | TEXT | 880025 |
| Addit_Info | TEXT | (empty) |

## Mapping: 1 STOCK row → 1 Product + 1 ProductVariant

| STOCK | Product | ProductVariant |
|-------|---------|----------------|
| Product_Name | name | — |
| — | product_url | — |
| Tax_Applied | tax_code_id | — |
| Supplier + Supp_Phone | supplier_id | — |
| — | added_by_id | — |
| — | metadata: { legacy_import: true } | — |
| Stock_Cat | categorizations | — |
| Stock_Code | — | code |
| — | — | selling_price, purchase_price, stock_level, reorder_level, order_quantity, unit_cost, items_per_unit, supplier_reference |
| Addit_Info | — | notes |
| Date_Added | created_at | created_at |

## Special Handling

1. **Tax_Applied** (e.g. "2"): Map to `tax_code_id` via a configurable mapping (legacy code → TaxCode record).
2. **Supplier + Supp_Phone**: `find_or_create` Supplier by name; use `find_or_create` by (name, phone) if duplicates exist.
3. **Stock_Cat**: `find_or_create` Category by name; add `product.categories << category`.
4. **Date_Added**: Set `created_at` on both Product and ProductVariant when creating.
5. **Metadata**: Set `metadata: { "legacy_import" => true }` on Product for imported records.
