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

ActiveRecord::Schema[8.1].define(version: 2026_02_15_144047) do
  # These are extensions that must be enabled in order to support this database
  enable_extension "pg_catalog.plpgsql"
  enable_extension "pg_trgm"

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
    t.datetime "updated_at", null: false
    t.index ["added_by_id"], name: "index_customers_on_added_by_id"
    t.index ["discarded_at"], name: "index_customers_on_discarded_at"
    t.index ["member_number"], name: "index_customers_on_member_number", unique: true
  end

  create_table "dashboard_metrics", force: :cascade do |t|
    t.datetime "computed_at", null: false
    t.datetime "created_at", null: false
    t.string "key", null: false
    t.datetime "updated_at", null: false
    t.decimal "value", precision: 20, scale: 4
    t.index ["key"], name: "index_dashboard_metrics_on_key", unique: true
  end

  create_table "pg_search_documents", force: :cascade do |t|
    t.text "content"
    t.datetime "created_at", null: false
    t.bigint "searchable_id"
    t.string "searchable_type"
    t.datetime "updated_at", null: false
    t.index ["searchable_type", "searchable_id"], name: "index_pg_search_documents_on_searchable"
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

  add_foreign_key "categorizations", "categories"
  add_foreign_key "customers", "users", column: "added_by_id"
  add_foreign_key "product_variants", "products"
  add_foreign_key "product_variants", "suppliers"
  add_foreign_key "products", "suppliers"
  add_foreign_key "products", "tax_codes"
  add_foreign_key "products", "users", column: "added_by_id"
  add_foreign_key "services", "tax_codes"
  add_foreign_key "services", "users", column: "added_by_id"
  add_foreign_key "sessions", "users"
  add_foreign_key "solid_queue_blocked_executions", "solid_queue_jobs", column: "job_id", on_delete: :cascade
  add_foreign_key "solid_queue_claimed_executions", "solid_queue_jobs", column: "job_id", on_delete: :cascade
  add_foreign_key "solid_queue_failed_executions", "solid_queue_jobs", column: "job_id", on_delete: :cascade
  add_foreign_key "solid_queue_ready_executions", "solid_queue_jobs", column: "job_id", on_delete: :cascade
  add_foreign_key "solid_queue_recurring_executions", "solid_queue_jobs", column: "job_id", on_delete: :cascade
  add_foreign_key "solid_queue_scheduled_executions", "solid_queue_jobs", column: "job_id", on_delete: :cascade
end
