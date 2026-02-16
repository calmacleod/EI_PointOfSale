class ReworkProductsAndAddShopify < ActiveRecord::Migration[8.1]
  def change
    # ── Product Groups (optional variant grouping for Shopify) ──────
    create_table :product_groups do |t|
      t.string :name, null: false
      t.string :shopify_product_id
      t.timestamps
    end

    # ── Drop old tables (no production data) ────────────────────────
    drop_table :product_variants, if_exists: true
    drop_table :products, if_exists: true

    # ── Recreate products as a flat, unified table ──────────────────
    create_table :products do |t|
      t.string  :code,               null: false
      t.string  :name,               null: false
      t.decimal :selling_price,      precision: 10, scale: 2
      t.decimal :purchase_price,     precision: 10, scale: 2
      t.integer :stock_level,        default: 0
      t.integer :reorder_level,      default: 0
      t.integer :order_quantity
      t.decimal :unit_cost,          precision: 10, scale: 2
      t.integer :items_per_unit,     default: 1
      t.string  :supplier_reference
      t.text    :notes
      t.string  :product_url
      t.jsonb   :metadata,           default: {}

      t.references :tax_code,      foreign_key: true, null: true
      t.references :supplier,      foreign_key: true, null: true
      t.references :added_by,      foreign_key: { to_table: :users }, null: true
      t.references :product_group, foreign_key: true, null: true

      # Shopify integration columns
      t.string   :shopify_product_id
      t.string   :shopify_variant_id
      t.string   :shopify_inventory_item_id
      t.boolean  :sync_to_shopify,  default: false
      t.datetime :shopify_synced_at

      # Soft-delete
      t.datetime :discarded_at

      t.timestamps
    end

    add_index :products, :code, unique: true
    add_index :products, :discarded_at
    add_index :products, :shopify_product_id
    add_index :products, :shopify_variant_id

    # ── Data Imports (track CSV import jobs) ────────────────────────
    create_table :data_imports do |t|
      t.string   :file_name
      t.string   :status,         default: "pending"
      t.integer  :total_rows
      t.integer  :processed_rows, default: 0
      t.integer  :created_count,  default: 0
      t.integer  :updated_count,  default: 0
      t.integer  :error_count,    default: 0
      t.jsonb    :errors_log,     default: []
      t.references :imported_by,  foreign_key: { to_table: :users }, null: true
      t.datetime :completed_at
      t.timestamps
    end
  end
end
