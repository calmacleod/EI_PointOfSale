# Legacy Stock Import

## Overview

The import tool allows admins to bulk-import products from a legacy CSV file (originally exported from an Access database). The import is accessed via **Admin > Settings > Data Import** and supports a preview-then-execute workflow with background processing.

## Source Format

The legacy CSV (`Stock.csv`) contains ~52,800 rows with the following columns:

| CSV Column | Type | Example | Maps to |
|------------|------|---------|---------|
| Stock_Code | string | 880025 | `product.code` |
| Product_Name | string | Brat Player Boston | `product.name` |
| Selling_Price | decimal | 7.99 | `product.selling_price` |
| Purchase_Price | decimal | 3.95 | `product.purchase_price` |
| Stock_Level | integer | 0 | `product.stock_level` |
| Tax_Applied | string | 2 | `product.tax_code_id` (mapped) |
| Date_Added | timestamp | 2007-03-29 | `product.created_at` (preserved) |
| Stock_Cat | string | NHL Novelties | Category (find-or-create) |
| Reorder_Level | integer | 0 | `product.reorder_level` |
| Supplier | string | JF Sports | Supplier (find-or-create) |
| Supp_Phone | string | 1-800-267-0513 | `supplier.phone` |
| Order2_Level | integer | 4 | `product.order_quantity` |
| OUnit_Cost | decimal | 3.95 | `product.unit_cost` |
| Items_Unit | integer | 1 | `product.items_per_unit` |
| Supp_Ref | string | 880025 | `product.supplier_reference` |
| Addit_Info | string | (notes) | `product.notes` |

**Ignored columns:** `Added_By`, `Fr_Rent_Pts`, `Pts_To_Rent`, `I_Image` (empty or deprecated).

## Mapping: 1 CSV row -> 1 Product

Each row maps directly to a single `Product` record in the flat product model:

```
CSV Row (Stock_Code: "880025", Product_Name: "Brat Player Boston")
  -> Product (code: "880025", name: "Brat Player Boston", ...)
```

## Tax Code Mapping

The legacy `Tax_Applied` values map to tax codes:

| Tax_Applied | Tax Code | Description |
|-------------|----------|-------------|
| `"1"` | EXEMPT | Books / tax-exempt items |
| `"2"` | HST | Standard HST (13%) |

The importer will find-or-create these TaxCode records automatically.

## Import Workflow

### 1. Upload (Admin > Data Import > Upload CSV)

Upload a CSV file from the import page. Two options:

- **Preview** -- parse the CSV and display a summary without persisting any product data
- **Import now** -- save the CSV and immediately enqueue a background import job

### 2. Preview

The preview shows:

- Total row count
- Detected categories (with count)
- Detected suppliers (with count)
- Duplicate code warnings (last occurrence is kept)
- Blank code warnings (rows will be skipped)
- Sample of the first 5 rows

From the preview page, you can choose to **Execute import** or go **Back** to re-upload.

### 3. Execute

The import runs as a background job (`Importers::StockImportJob`) via Solid Queue. Progress is tracked in the `data_imports` table and displayed on the import status page.

The import:

1. **Pre-creates** all Suppliers and Categories found in the CSV (find-or-create)
2. **Deduplicates** by `Stock_Code` (keeps the last occurrence if duplicates exist)
3. **Skips** rows with blank `Stock_Code`
4. **Upserts** products (find-or-initialize by code, then save)
5. **Preserves** the original `Date_Added` as `created_at` for new records
6. **Assigns** categories to products
7. **Updates progress** every 100 rows

### Tracking

The `DataImport` model tracks:

| Field | Description |
|-------|-------------|
| `status` | `pending`, `processing`, `completed`, or `failed` |
| `total_rows` | Total unique rows to process |
| `processed_rows` | Rows processed so far |
| `created_count` | New products created |
| `updated_count` | Existing products updated |
| `error_count` | Rows that failed |
| `errors_log` | JSONB array of error details `[{row, code, error}]` |
| `completed_at` | Timestamp when import finished |

## Re-importing

The import is idempotent -- running the same CSV again will update existing products (matched by `code`) rather than creating duplicates.

## File Locations

| Purpose | Path |
|---------|------|
| Import service | `app/services/importers/stock_importer.rb` |
| Background job | `app/jobs/importers/stock_import_job.rb` |
| DataImport model | `app/models/data_import.rb` |
| Controller | `app/controllers/admin_area/imports_controller.rb` |
| Views | `app/views/admin_area/imports/` |
| Service tests | `test/services/importers/stock_importer_test.rb` |
| Controller tests | `test/controllers/admin_area/imports_controller_test.rb` |
