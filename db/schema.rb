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

ActiveRecord::Schema[8.1].define(version: 2026_02_18_000002) do
  # These are extensions that must be enabled in order to support this database
  enable_extension "pg_catalog.plpgsql"
  enable_extension "pg_trgm"

  create_table "active_storage_attachments", force: :cascade do |t|
    t.bigint "blob_id", null: false
    t.datetime "created_at", null: false
    t.string "name", null: false
    t.bigint "record_id", null: false
    t.string "record_type", null: false
    t.index ["blob_id"], name: "index_active_storage_attachments_on_blob_id"
    t.index ["record_type", "record_id", "name", "blob_id"], name: "index_active_storage_attachments_uniqueness", unique: true
  end

  create_table "active_storage_blobs", force: :cascade do |t|
    t.bigint "byte_size", null: false
    t.string "checksum"
    t.string "content_type"
    t.datetime "created_at", null: false
    t.string "filename", null: false
    t.string "key", null: false
    t.text "metadata"
    t.string "service_name", null: false
    t.index ["key"], name: "index_active_storage_blobs_on_key", unique: true
  end

  create_table "active_storage_variant_records", force: :cascade do |t|
    t.bigint "blob_id", null: false
    t.string "variation_digest", null: false
    t.index ["blob_id", "variation_digest"], name: "index_active_storage_variant_records_uniqueness", unique: true
  end

  create_table "audits", force: :cascade do |t|
    t.string "action"
    t.integer "associated_id"
    t.string "associated_type"
    t.integer "auditable_id"
    t.string "auditable_type"
    t.jsonb "audited_changes"
    t.string "comment"
    t.datetime "created_at"
    t.string "remote_address"
    t.string "request_uuid"
    t.integer "user_id"
    t.string "user_type"
    t.string "username"
    t.integer "version", default: 0
    t.index ["associated_type", "associated_id"], name: "associated_index"
    t.index ["auditable_type", "auditable_id", "version"], name: "auditable_index"
    t.index ["created_at"], name: "index_audits_on_created_at"
    t.index ["request_uuid"], name: "index_audits_on_request_uuid"
    t.index ["user_id", "user_type"], name: "user_index"
  end

  create_table "cash_drawer_sessions", force: :cascade do |t|
    t.datetime "closed_at"
    t.bigint "closed_by_id"
    t.jsonb "closing_counts"
    t.integer "closing_total_cents"
    t.datetime "created_at", null: false
    t.text "notes"
    t.datetime "opened_at", null: false
    t.bigint "opened_by_id", null: false
    t.jsonb "opening_counts", default: {}, null: false
    t.integer "opening_total_cents", null: false
    t.datetime "updated_at", null: false
    t.index ["closed_at"], name: "index_cash_drawer_sessions_on_closed_at"
    t.index ["closed_by_id"], name: "index_cash_drawer_sessions_on_closed_by_id"
    t.index ["opened_at"], name: "index_cash_drawer_sessions_on_opened_at"
    t.index ["opened_by_id"], name: "index_cash_drawer_sessions_on_opened_by_id"
  end

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
    t.integer "account_status"
    t.boolean "active", default: true, null: false
    t.bigint "added_by_id"
    t.string "address_line1"
    t.string "address_line2"
    t.text "alert"
    t.string "city"
    t.string "country"
    t.datetime "created_at", null: false
    t.date "date_of_birth"
    t.datetime "discarded_at"
    t.string "email"
    t.datetime "joining_date"
    t.string "member_number"
    t.string "name"
    t.text "notes"
    t.string "phone"
    t.string "postal_code"
    t.string "province"
    t.string "status_card_number"
    t.bigint "tax_code_id"
    t.datetime "updated_at", null: false
    t.index ["added_by_id"], name: "index_customers_on_added_by_id"
    t.index ["discarded_at"], name: "index_customers_on_discarded_at"
    t.index ["member_number"], name: "index_customers_on_member_number", unique: true
    t.index ["tax_code_id"], name: "index_customers_on_tax_code_id"
  end

  create_table "dashboard_metrics", force: :cascade do |t|
    t.datetime "computed_at", null: false
    t.datetime "created_at", null: false
    t.string "key", null: false
    t.datetime "updated_at", null: false
    t.decimal "value", precision: 20, scale: 4
    t.index ["key"], name: "index_dashboard_metrics_on_key", unique: true
  end

  create_table "data_imports", force: :cascade do |t|
    t.datetime "completed_at"
    t.datetime "created_at", null: false
    t.integer "created_count", default: 0
    t.integer "error_count", default: 0
    t.jsonb "errors_log", default: []
    t.string "file_name"
    t.bigint "imported_by_id"
    t.integer "processed_rows", default: 0
    t.string "status", default: "pending"
    t.integer "total_rows"
    t.datetime "updated_at", null: false
    t.integer "updated_count", default: 0
    t.index ["imported_by_id"], name: "index_data_imports_on_imported_by_id"
  end

  create_table "discount_items", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.bigint "discount_id", null: false
    t.bigint "discountable_id", null: false
    t.string "discountable_type", null: false
    t.datetime "updated_at", null: false
    t.index ["discount_id", "discountable_type", "discountable_id"], name: "index_discount_items_uniqueness", unique: true
    t.index ["discount_id"], name: "index_discount_items_on_discount_id"
    t.index ["discountable_type", "discountable_id"], name: "index_discount_items_on_discountable"
  end

  create_table "discounts", force: :cascade do |t|
    t.boolean "active", default: true, null: false
    t.boolean "applies_to_all", default: false, null: false
    t.datetime "created_at", null: false
    t.text "description"
    t.datetime "discarded_at"
    t.integer "discount_type", null: false
    t.datetime "ends_at"
    t.string "name", null: false
    t.datetime "starts_at"
    t.datetime "updated_at", null: false
    t.decimal "value", precision: 10, scale: 2, null: false
    t.index ["active"], name: "index_discounts_on_active"
    t.index ["discarded_at"], name: "index_discounts_on_discarded_at"
  end

  create_table "gift_certificates", force: :cascade do |t|
    t.datetime "activated_at"
    t.string "code", null: false
    t.datetime "created_at", null: false
    t.bigint "customer_id"
    t.decimal "initial_amount", precision: 10, scale: 2, null: false
    t.bigint "issued_by_id"
    t.decimal "remaining_balance", precision: 10, scale: 2, null: false
    t.bigint "sold_on_order_id"
    t.integer "status", default: 0, null: false
    t.datetime "updated_at", null: false
    t.datetime "voided_at"
    t.index ["code"], name: "index_gift_certificates_on_code", unique: true
    t.index ["customer_id"], name: "index_gift_certificates_on_customer_id"
    t.index ["issued_by_id"], name: "index_gift_certificates_on_issued_by_id"
    t.index ["sold_on_order_id"], name: "index_gift_certificates_on_sold_on_order_id"
    t.index ["status"], name: "index_gift_certificates_on_status"
  end

  create_table "notifications", force: :cascade do |t|
    t.text "body"
    t.string "category"
    t.datetime "created_at", null: false
    t.boolean "persistent", default: true, null: false
    t.datetime "read_at"
    t.string "title", null: false
    t.datetime "updated_at", null: false
    t.string "url"
    t.bigint "user_id", null: false
    t.index ["user_id", "read_at"], name: "index_notifications_on_user_id_and_read_at"
    t.index ["user_id"], name: "index_notifications_on_user_id"
  end

  create_table "order_discount_items", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.bigint "order_discount_id", null: false
    t.bigint "order_line_id", null: false
    t.datetime "updated_at", null: false
    t.index ["order_discount_id", "order_line_id"], name: "idx_discount_items_uniqueness", unique: true
    t.index ["order_discount_id"], name: "index_order_discount_items_on_order_discount_id"
    t.index ["order_line_id"], name: "index_order_discount_items_on_order_line_id"
  end

  create_table "order_discounts", force: :cascade do |t|
    t.bigint "applied_by_id"
    t.decimal "calculated_amount", precision: 10, scale: 2, default: "0.0"
    t.datetime "created_at", null: false
    t.bigint "discount_id"
    t.integer "discount_type", null: false
    t.string "name", null: false
    t.bigint "order_id", null: false
    t.integer "scope", default: 0, null: false
    t.datetime "updated_at", null: false
    t.decimal "value", precision: 10, scale: 2, null: false
    t.index ["applied_by_id"], name: "index_order_discounts_on_applied_by_id"
    t.index ["discount_id"], name: "index_order_discounts_on_discount_id"
    t.index ["order_id"], name: "index_order_discounts_on_order_id"
  end

  create_table "order_events", force: :cascade do |t|
    t.bigint "actor_id", null: false
    t.datetime "created_at", null: false
    t.jsonb "data", default: {}
    t.string "event_type", null: false
    t.bigint "order_id", null: false
    t.index ["actor_id"], name: "index_order_events_on_actor_id"
    t.index ["order_id", "created_at"], name: "index_order_events_on_order_id_and_created_at"
    t.index ["order_id"], name: "index_order_events_on_order_id"
  end

  create_table "order_lines", force: :cascade do |t|
    t.string "code"
    t.datetime "created_at", null: false
    t.decimal "discount_amount", precision: 10, scale: 2, default: "0.0"
    t.decimal "line_total", precision: 10, scale: 2, null: false
    t.string "name", null: false
    t.bigint "order_id", null: false
    t.integer "position", default: 0
    t.integer "quantity", default: 1, null: false
    t.bigint "sellable_id", null: false
    t.string "sellable_type", null: false
    t.decimal "tax_amount", precision: 10, scale: 2, default: "0.0"
    t.bigint "tax_code_id"
    t.decimal "tax_rate", precision: 5, scale: 4, default: "0.0"
    t.decimal "unit_price", precision: 10, scale: 2, null: false
    t.datetime "updated_at", null: false
    t.index ["order_id", "position"], name: "index_order_lines_on_order_id_and_position"
    t.index ["order_id"], name: "index_order_lines_on_order_id"
    t.index ["sellable_type", "sellable_id"], name: "index_order_lines_on_sellable"
    t.index ["tax_code_id"], name: "index_order_lines_on_tax_code_id"
  end

  create_table "order_payments", force: :cascade do |t|
    t.decimal "amount", precision: 10, scale: 2, null: false
    t.decimal "amount_tendered", precision: 10, scale: 2
    t.decimal "change_given", precision: 10, scale: 2
    t.datetime "created_at", null: false
    t.bigint "gift_certificate_id"
    t.bigint "order_id", null: false
    t.integer "payment_method", null: false
    t.bigint "received_by_id"
    t.string "reference"
    t.datetime "updated_at", null: false
    t.index ["gift_certificate_id"], name: "index_order_payments_on_gift_certificate_id"
    t.index ["order_id"], name: "index_order_payments_on_order_id"
    t.index ["received_by_id"], name: "index_order_payments_on_received_by_id"
  end

  create_table "orders", force: :cascade do |t|
    t.bigint "cash_drawer_session_id"
    t.datetime "completed_at"
    t.datetime "created_at", null: false
    t.bigint "created_by_id", null: false
    t.bigint "customer_id"
    t.datetime "discarded_at"
    t.decimal "discount_total", precision: 10, scale: 2, default: "0.0"
    t.datetime "held_at"
    t.jsonb "metadata", default: {}, null: false
    t.text "notes"
    t.string "number", null: false
    t.integer "status", default: 0, null: false
    t.decimal "subtotal", precision: 10, scale: 2, default: "0.0"
    t.boolean "tax_exempt", default: false, null: false
    t.string "tax_exempt_number"
    t.decimal "tax_total", precision: 10, scale: 2, default: "0.0"
    t.decimal "total", precision: 10, scale: 2, default: "0.0"
    t.datetime "updated_at", null: false
    t.index ["cash_drawer_session_id"], name: "index_orders_on_cash_drawer_session_id"
    t.index ["completed_at"], name: "index_orders_on_completed_at"
    t.index ["created_by_id"], name: "index_orders_on_created_by_id"
    t.index ["customer_id"], name: "index_orders_on_customer_id"
    t.index ["discarded_at"], name: "index_orders_on_discarded_at"
    t.index ["metadata"], name: "index_orders_on_metadata", using: :gin
    t.index ["number"], name: "index_orders_on_number", unique: true
    t.index ["status"], name: "index_orders_on_status"
  end

  create_table "pg_search_documents", force: :cascade do |t|
    t.text "content"
    t.datetime "created_at", null: false
    t.bigint "searchable_id"
    t.string "searchable_type"
    t.datetime "updated_at", null: false
    t.index ["searchable_type", "searchable_id"], name: "index_pg_search_documents_on_searchable"
  end

  create_table "product_groups", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.string "name", null: false
    t.string "shopify_product_id"
    t.datetime "updated_at", null: false
  end

  create_table "products", force: :cascade do |t|
    t.bigint "added_by_id"
    t.string "code", null: false
    t.datetime "created_at", null: false
    t.datetime "discarded_at"
    t.integer "items_per_unit", default: 1
    t.jsonb "metadata", default: {}
    t.string "name", null: false
    t.text "notes"
    t.integer "order_quantity"
    t.bigint "product_group_id"
    t.string "product_url"
    t.decimal "purchase_price", precision: 10, scale: 2
    t.integer "reorder_level", default: 0
    t.decimal "selling_price", precision: 10, scale: 2
    t.string "shopify_inventory_item_id"
    t.string "shopify_product_id"
    t.datetime "shopify_synced_at"
    t.string "shopify_variant_id"
    t.integer "stock_level", default: 0
    t.bigint "supplier_id"
    t.string "supplier_reference"
    t.boolean "sync_to_shopify", default: false
    t.bigint "tax_code_id"
    t.decimal "unit_cost", precision: 10, scale: 2
    t.datetime "updated_at", null: false
    t.index ["added_by_id"], name: "index_products_on_added_by_id"
    t.index ["code"], name: "index_products_on_code", unique: true
    t.index ["discarded_at"], name: "index_products_on_discarded_at"
    t.index ["product_group_id"], name: "index_products_on_product_group_id"
    t.index ["shopify_product_id"], name: "index_products_on_shopify_product_id"
    t.index ["shopify_variant_id"], name: "index_products_on_shopify_variant_id"
    t.index ["supplier_id"], name: "index_products_on_supplier_id"
    t.index ["tax_code_id"], name: "index_products_on_tax_code_id"
  end

  create_table "push_subscriptions", force: :cascade do |t|
    t.string "auth_key", null: false
    t.datetime "created_at", null: false
    t.text "endpoint", null: false
    t.string "p256dh_key", null: false
    t.datetime "updated_at", null: false
    t.bigint "user_id", null: false
    t.index ["user_id", "endpoint"], name: "index_push_subscriptions_on_user_id_and_endpoint", unique: true
    t.index ["user_id"], name: "index_push_subscriptions_on_user_id"
  end

  create_table "receipt_templates", force: :cascade do |t|
    t.boolean "active", default: false, null: false
    t.integer "chars_per_line", default: 48, null: false
    t.datetime "created_at", null: false
    t.text "footer_text"
    t.text "header_text"
    t.string "name", null: false
    t.integer "paper_width_mm", default: 80, null: false
    t.boolean "show_cashier_name", default: true, null: false
    t.boolean "show_date_time", default: true, null: false
    t.boolean "show_logo", default: true, null: false
    t.boolean "show_store_address", default: true, null: false
    t.boolean "show_store_email", default: false, null: false
    t.boolean "show_store_name", default: true, null: false
    t.boolean "show_store_phone", default: true, null: false
    t.boolean "trim_logo", default: false, null: false
    t.datetime "updated_at", null: false
  end

  create_table "refund_lines", force: :cascade do |t|
    t.decimal "amount", precision: 10, scale: 2, null: false
    t.bigint "order_line_id", null: false
    t.integer "quantity", null: false
    t.bigint "refund_id", null: false
    t.boolean "restock", default: false, null: false
    t.index ["order_line_id"], name: "index_refund_lines_on_order_line_id"
    t.index ["refund_id"], name: "index_refund_lines_on_refund_id"
  end

  create_table "refunds", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.bigint "order_id", null: false
    t.bigint "processed_by_id", null: false
    t.text "reason"
    t.string "refund_number", null: false
    t.integer "refund_type", null: false
    t.decimal "total", precision: 10, scale: 2, null: false
    t.index ["order_id"], name: "index_refunds_on_order_id"
    t.index ["processed_by_id"], name: "index_refunds_on_processed_by_id"
    t.index ["refund_number"], name: "index_refunds_on_refund_number", unique: true
  end

  create_table "reports", force: :cascade do |t|
    t.datetime "completed_at"
    t.datetime "created_at", null: false
    t.text "error_message"
    t.bigint "generated_by_id", null: false
    t.jsonb "parameters", default: {}, null: false
    t.string "report_type", null: false
    t.jsonb "result_data"
    t.datetime "started_at"
    t.string "status", default: "pending", null: false
    t.string "title", null: false
    t.datetime "updated_at", null: false
    t.index ["created_at"], name: "index_reports_on_created_at"
    t.index ["generated_by_id"], name: "index_reports_on_generated_by_id"
    t.index ["report_type"], name: "index_reports_on_report_type"
    t.index ["status"], name: "index_reports_on_status"
  end

  create_table "saved_queries", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.string "name", null: false
    t.jsonb "query_params", default: {}, null: false
    t.string "resource_type", null: false
    t.datetime "updated_at", null: false
    t.bigint "user_id", null: false
    t.index ["user_id", "resource_type"], name: "index_saved_queries_on_user_id_and_resource_type"
    t.index ["user_id"], name: "index_saved_queries_on_user_id"
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

  create_table "solid_queue_blocked_executions", force: :cascade do |t|
    t.string "concurrency_key", null: false
    t.datetime "created_at", null: false
    t.datetime "expires_at", null: false
    t.bigint "job_id", null: false
    t.integer "priority", default: 0, null: false
    t.string "queue_name", null: false
    t.index ["concurrency_key", "priority", "job_id"], name: "index_solid_queue_blocked_executions_for_release"
    t.index ["expires_at", "concurrency_key"], name: "index_solid_queue_blocked_executions_for_maintenance"
    t.index ["job_id"], name: "index_solid_queue_blocked_executions_on_job_id", unique: true
  end

  create_table "solid_queue_claimed_executions", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.bigint "job_id", null: false
    t.bigint "process_id"
    t.index ["job_id"], name: "index_solid_queue_claimed_executions_on_job_id", unique: true
    t.index ["process_id", "job_id"], name: "index_solid_queue_claimed_executions_on_process_id_and_job_id"
  end

  create_table "solid_queue_failed_executions", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.text "error"
    t.bigint "job_id", null: false
    t.index ["job_id"], name: "index_solid_queue_failed_executions_on_job_id", unique: true
  end

  create_table "solid_queue_jobs", force: :cascade do |t|
    t.string "active_job_id"
    t.text "arguments"
    t.string "class_name", null: false
    t.string "concurrency_key"
    t.datetime "created_at", null: false
    t.datetime "finished_at"
    t.integer "priority", default: 0, null: false
    t.string "queue_name", null: false
    t.datetime "scheduled_at"
    t.datetime "updated_at", null: false
    t.index ["active_job_id"], name: "index_solid_queue_jobs_on_active_job_id"
    t.index ["class_name"], name: "index_solid_queue_jobs_on_class_name"
    t.index ["finished_at"], name: "index_solid_queue_jobs_on_finished_at"
    t.index ["queue_name", "finished_at"], name: "index_solid_queue_jobs_for_filtering"
    t.index ["scheduled_at", "finished_at"], name: "index_solid_queue_jobs_for_alerting"
  end

  create_table "solid_queue_pauses", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.string "queue_name", null: false
    t.index ["queue_name"], name: "index_solid_queue_pauses_on_queue_name", unique: true
  end

  create_table "solid_queue_processes", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.string "hostname"
    t.string "kind", null: false
    t.datetime "last_heartbeat_at", null: false
    t.text "metadata"
    t.string "name", null: false
    t.integer "pid", null: false
    t.bigint "supervisor_id"
    t.index ["last_heartbeat_at"], name: "index_solid_queue_processes_on_last_heartbeat_at"
    t.index ["name", "supervisor_id"], name: "index_solid_queue_processes_on_name_and_supervisor_id", unique: true
    t.index ["supervisor_id"], name: "index_solid_queue_processes_on_supervisor_id"
  end

  create_table "solid_queue_ready_executions", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.bigint "job_id", null: false
    t.integer "priority", default: 0, null: false
    t.string "queue_name", null: false
    t.index ["job_id"], name: "index_solid_queue_ready_executions_on_job_id", unique: true
    t.index ["priority", "job_id"], name: "index_solid_queue_poll_all"
    t.index ["queue_name", "priority", "job_id"], name: "index_solid_queue_poll_by_queue"
  end

  create_table "solid_queue_recurring_executions", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.bigint "job_id", null: false
    t.datetime "run_at", null: false
    t.string "task_key", null: false
    t.index ["job_id"], name: "index_solid_queue_recurring_executions_on_job_id", unique: true
    t.index ["task_key", "run_at"], name: "index_solid_queue_recurring_executions_on_task_key_and_run_at", unique: true
  end

  create_table "solid_queue_recurring_tasks", force: :cascade do |t|
    t.text "arguments"
    t.string "class_name"
    t.string "command", limit: 2048
    t.datetime "created_at", null: false
    t.text "description"
    t.string "key", null: false
    t.integer "priority", default: 0
    t.string "queue_name"
    t.string "schedule", null: false
    t.boolean "static", default: true, null: false
    t.datetime "updated_at", null: false
    t.index ["key"], name: "index_solid_queue_recurring_tasks_on_key", unique: true
    t.index ["static"], name: "index_solid_queue_recurring_tasks_on_static"
  end

  create_table "solid_queue_scheduled_executions", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.bigint "job_id", null: false
    t.integer "priority", default: 0, null: false
    t.string "queue_name", null: false
    t.datetime "scheduled_at", null: false
    t.index ["job_id"], name: "index_solid_queue_scheduled_executions_on_job_id", unique: true
    t.index ["scheduled_at", "priority", "job_id"], name: "index_solid_queue_dispatch_all"
  end

  create_table "solid_queue_semaphores", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.datetime "expires_at", null: false
    t.string "key", null: false
    t.datetime "updated_at", null: false
    t.integer "value", default: 1, null: false
    t.index ["expires_at"], name: "index_solid_queue_semaphores_on_expires_at"
    t.index ["key", "value"], name: "index_solid_queue_semaphores_on_key_and_value"
    t.index ["key"], name: "index_solid_queue_semaphores_on_key", unique: true
  end

  create_table "store_tasks", force: :cascade do |t|
    t.bigint "assigned_to_id"
    t.text "body"
    t.datetime "created_at", null: false
    t.date "due_date"
    t.integer "status", default: 0, null: false
    t.string "title", null: false
    t.datetime "updated_at", null: false
    t.index ["assigned_to_id"], name: "index_store_tasks_on_assigned_to_id"
    t.index ["due_date"], name: "index_store_tasks_on_due_date"
    t.index ["status"], name: "index_store_tasks_on_status"
  end

  create_table "stores", force: :cascade do |t|
    t.string "accent_color", default: "teal", null: false
    t.string "address_line1"
    t.string "address_line2"
    t.string "city"
    t.string "country"
    t.datetime "created_at", null: false
    t.string "email"
    t.string "name"
    t.string "phone"
    t.string "postal_code"
    t.string "province"
    t.datetime "updated_at", null: false
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

  create_table "terminal_reconciliations", force: :cascade do |t|
    t.bigint "cash_drawer_session_id", null: false
    t.datetime "created_at", null: false
    t.decimal "credit_total", precision: 10, scale: 2, default: "0.0", null: false
    t.decimal "debit_total", precision: 10, scale: 2, default: "0.0", null: false
    t.decimal "expected_credit_total", precision: 10, scale: 2
    t.decimal "expected_debit_total", precision: 10, scale: 2
    t.text "notes"
    t.datetime "reconciled_at"
    t.bigint "reconciled_by_id"
    t.datetime "updated_at", null: false
    t.index ["cash_drawer_session_id"], name: "index_terminal_reconciliations_on_cash_drawer_session_id", unique: true
    t.index ["reconciled_by_id"], name: "index_terminal_reconciliations_on_reconciled_by_id"
  end

  create_table "users", force: :cascade do |t|
    t.boolean "active", default: true, null: false
    t.datetime "created_at", null: false
    t.string "dashboard_metric_keys", default: [], array: true
    t.string "email_address", null: false
    t.string "font_size", default: "default", null: false
    t.string "name"
    t.text "notes"
    t.string "password_digest", null: false
    t.string "phone"
    t.boolean "sidebar_collapsed", default: false, null: false
    t.string "theme", default: "light", null: false
    t.string "type", default: "Common", null: false
    t.datetime "updated_at", null: false
    t.index ["email_address"], name: "index_users_on_email_address", unique: true
  end

  add_foreign_key "active_storage_attachments", "active_storage_blobs", column: "blob_id"
  add_foreign_key "active_storage_variant_records", "active_storage_blobs", column: "blob_id"
  add_foreign_key "cash_drawer_sessions", "users", column: "closed_by_id"
  add_foreign_key "cash_drawer_sessions", "users", column: "opened_by_id"
  add_foreign_key "categorizations", "categories"
  add_foreign_key "customers", "tax_codes"
  add_foreign_key "customers", "users", column: "added_by_id"
  add_foreign_key "data_imports", "users", column: "imported_by_id"
  add_foreign_key "discount_items", "discounts"
  add_foreign_key "gift_certificates", "customers"
  add_foreign_key "gift_certificates", "orders", column: "sold_on_order_id"
  add_foreign_key "gift_certificates", "users", column: "issued_by_id"
  add_foreign_key "notifications", "users"
  add_foreign_key "order_discount_items", "order_discounts"
  add_foreign_key "order_discount_items", "order_lines"
  add_foreign_key "order_discounts", "discounts"
  add_foreign_key "order_discounts", "orders"
  add_foreign_key "order_discounts", "users", column: "applied_by_id"
  add_foreign_key "order_events", "orders"
  add_foreign_key "order_events", "users", column: "actor_id"
  add_foreign_key "order_lines", "orders"
  add_foreign_key "order_lines", "tax_codes"
  add_foreign_key "order_payments", "gift_certificates"
  add_foreign_key "order_payments", "orders"
  add_foreign_key "order_payments", "users", column: "received_by_id"
  add_foreign_key "orders", "cash_drawer_sessions"
  add_foreign_key "orders", "customers"
  add_foreign_key "orders", "users", column: "created_by_id"
  add_foreign_key "products", "product_groups"
  add_foreign_key "products", "suppliers"
  add_foreign_key "products", "tax_codes"
  add_foreign_key "products", "users", column: "added_by_id"
  add_foreign_key "push_subscriptions", "users"
  add_foreign_key "refund_lines", "order_lines"
  add_foreign_key "refund_lines", "refunds"
  add_foreign_key "refunds", "orders"
  add_foreign_key "refunds", "users", column: "processed_by_id"
  add_foreign_key "reports", "users", column: "generated_by_id"
  add_foreign_key "saved_queries", "users"
  add_foreign_key "services", "tax_codes"
  add_foreign_key "services", "users", column: "added_by_id"
  add_foreign_key "sessions", "users"
  add_foreign_key "solid_queue_blocked_executions", "solid_queue_jobs", column: "job_id", on_delete: :cascade
  add_foreign_key "solid_queue_claimed_executions", "solid_queue_jobs", column: "job_id", on_delete: :cascade
  add_foreign_key "solid_queue_failed_executions", "solid_queue_jobs", column: "job_id", on_delete: :cascade
  add_foreign_key "solid_queue_ready_executions", "solid_queue_jobs", column: "job_id", on_delete: :cascade
  add_foreign_key "solid_queue_recurring_executions", "solid_queue_jobs", column: "job_id", on_delete: :cascade
  add_foreign_key "solid_queue_scheduled_executions", "solid_queue_jobs", column: "job_id", on_delete: :cascade
  add_foreign_key "store_tasks", "users", column: "assigned_to_id"
  add_foreign_key "terminal_reconciliations", "cash_drawer_sessions"
  add_foreign_key "terminal_reconciliations", "users", column: "reconciled_by_id"
end
