# This file is auto-generated from the current state of the database. Instead
# of editing this file, please use the migrations feature of Active Record to
# incrementally modify your database, and then regenerate this schema definition.
#
# This file is the source Rails uses to define your schema when running `bin/rails
# db:schema:load`. When creating a new database, `bin/rails db:schema:load` tends to
# be faster and is potentially less error prone than running all of your
# migrations from scratch. Old migrations may fail to apply correctly if those
# migrations use external dependencies or application code.
#
# It's strongly recommended that you check this file into your version control system.

ActiveRecord::Schema[8.1].define(version: 2026_02_14_000007) do
  # These are extensions that must be enabled in order to support this database
  enable_extension "pg_catalog.plpgsql"

  create_table "categories", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.datetime "discarded_at"
    t.string "name", null: false
    t.datetime "updated_at", null: false
    t.index ["discarded_at"], name: "index_categories_on_discarded_at"
    t.index ["name"], name: "index_categories_on_name", unique: true
  end

  create_table "categorizations", force: :cascade do |t|
    t.bigint "categorizable_id", null: false
    t.string "categorizable_type", null: false
    t.bigint "category_id", null: false
    t.datetime "created_at", null: false
    t.datetime "discarded_at"
    t.datetime "updated_at", null: false
    t.index ["categorizable_type", "categorizable_id", "category_id"], name: "index_categorizations_on_categorizable_and_category", unique: true
    t.index ["categorizable_type", "categorizable_id"], name: "index_categorizations_on_categorizable"
    t.index ["category_id"], name: "index_categorizations_on_category_id"
    t.index ["discarded_at"], name: "index_categorizations_on_discarded_at"
  end

  create_table "customers", force: :cascade do |t|
    t.boolean "active", default: true, null: false
    t.datetime "created_at", null: false
    t.string "email"
    t.datetime "joining_date"
    t.string "name"
    t.text "notes"
    t.string "phone"
    t.datetime "updated_at", null: false
  end

  create_table "product_variants", force: :cascade do |t|
    t.string "code", null: false
    t.datetime "created_at", null: false
    t.datetime "discarded_at"
    t.decimal "items_per_unit", precision: 12, scale: 4
    t.string "name"
    t.text "notes"
    t.jsonb "option_values", default: {}
    t.decimal "order_quantity", precision: 12, scale: 4
    t.bigint "product_id", null: false
    t.decimal "purchase_price", precision: 10, scale: 2
    t.decimal "reorder_level", precision: 12, scale: 4, default: "0.0"
    t.decimal "selling_price", precision: 10, scale: 2
    t.decimal "stock_level", precision: 12, scale: 4, default: "0.0"
    t.bigint "supplier_id"
    t.string "supplier_reference"
    t.decimal "unit_cost", precision: 10, scale: 2
    t.datetime "updated_at", null: false
    t.index ["code"], name: "index_product_variants_on_code", unique: true
    t.index ["discarded_at"], name: "index_product_variants_on_discarded_at"
    t.index ["product_id"], name: "index_product_variants_on_product_id"
    t.index ["supplier_id"], name: "index_product_variants_on_supplier_id"
  end

  create_table "products", force: :cascade do |t|
    t.bigint "added_by_id"
    t.datetime "created_at", null: false
    t.datetime "discarded_at"
    t.jsonb "metadata", default: {}
    t.string "name", null: false
    t.string "product_url"
    t.bigint "supplier_id"
    t.bigint "tax_code_id"
    t.datetime "updated_at", null: false
    t.index ["added_by_id"], name: "index_products_on_added_by_id"
    t.index ["discarded_at"], name: "index_products_on_discarded_at"
    t.index ["supplier_id"], name: "index_products_on_supplier_id"
    t.index ["tax_code_id"], name: "index_products_on_tax_code_id"
  end

  create_table "services", force: :cascade do |t|
    t.bigint "added_by_id"
    t.string "code"
    t.datetime "created_at", null: false
    t.text "description"
    t.datetime "discarded_at"
    t.jsonb "metadata", default: {}
    t.string "name", null: false
    t.decimal "price", precision: 10, scale: 2, null: false
    t.bigint "tax_code_id"
    t.datetime "updated_at", null: false
    t.index ["added_by_id"], name: "index_services_on_added_by_id"
    t.index ["code"], name: "index_services_on_code", unique: true
    t.index ["discarded_at"], name: "index_services_on_discarded_at"
    t.index ["tax_code_id"], name: "index_services_on_tax_code_id"
  end

  create_table "sessions", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.string "ip_address"
    t.datetime "updated_at", null: false
    t.string "user_agent"
    t.bigint "user_id", null: false
    t.index ["user_id"], name: "index_sessions_on_user_id"
  end

  create_table "suppliers", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.datetime "discarded_at"
    t.string "name", null: false
    t.string "phone"
    t.datetime "updated_at", null: false
    t.index ["discarded_at"], name: "index_suppliers_on_discarded_at"
  end

  create_table "tax_codes", force: :cascade do |t|
    t.string "code", null: false
    t.datetime "created_at", null: false
    t.datetime "discarded_at"
    t.string "exemption_type"
    t.string "name", null: false
    t.text "notes"
    t.string "province_code"
    t.decimal "rate", precision: 5, scale: 4, default: "0.0"
    t.datetime "updated_at", null: false
    t.index ["code"], name: "index_tax_codes_on_code", unique: true
    t.index ["discarded_at"], name: "index_tax_codes_on_discarded_at"
  end

  create_table "users", force: :cascade do |t|
    t.boolean "active", default: true, null: false
    t.datetime "created_at", null: false
    t.string "email_address", null: false
    t.string "name"
    t.text "notes"
    t.string "password_digest", null: false
    t.string "phone"
    t.string "type", default: "Common", null: false
    t.datetime "updated_at", null: false
    t.index ["email_address"], name: "index_users_on_email_address", unique: true
  end

  add_foreign_key "categorizations", "categories"
  add_foreign_key "product_variants", "products"
  add_foreign_key "product_variants", "suppliers"
  add_foreign_key "products", "suppliers"
  add_foreign_key "products", "tax_codes"
  add_foreign_key "products", "users", column: "added_by_id"
  add_foreign_key "services", "tax_codes"
  add_foreign_key "services", "users", column: "added_by_id"
  add_foreign_key "sessions", "users"
end
