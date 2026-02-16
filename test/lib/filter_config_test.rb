# frozen_string_literal: true

require "test_helper"

class FilterConfigTest < ActiveSupport::TestCase
  setup do
    @config = FilterConfig.new(:products, "/products",
                               sort_default: "name", sort_default_direction: "asc") do |f|
      f.association  :supplier_id, label: "Supplier", collection: -> { Supplier.all }
      f.boolean      :active,      label: "Active"
      f.select       :status,      label: "Status", options: [ %w[Open open], %w[Closed closed] ]
      f.number_range :price,       label: "Price"
      f.date_range   :created_at,  label: "Created"

      f.column :name,  label: "Name",    default: true,  sortable: true
      f.column :price, label: "Price",   default: true,  sortable: true
      f.column :notes, label: "Notes",   default: false, sortable: false
    end
  end

  # --- DSL tests ---

  test "registers all filter types" do
    types = @config.filters.map(&:type)
    assert_includes types, :association
    assert_includes types, :boolean
    assert_includes types, :select
    assert_includes types, :number_range
    assert_includes types, :date_range
  end

  test "registers columns" do
    assert_equal 3, @config.columns.size
    assert_equal :name, @config.columns.first.key
  end

  test "sortable_columns returns only sortable column keys" do
    assert_equal %w[name price], @config.sortable_columns
  end

  test "default_columns returns only default column keys" do
    assert_equal %w[name price], @config.default_columns
  end

  test "stores resource name and search path" do
    assert_equal "products", @config.resource_name
    assert_equal "/products", @config.search_path
  end

  test "stores sort defaults" do
    assert_equal "name", @config.sort_default
    assert_equal "asc", @config.sort_default_direction
  end

  # --- Param keys ---

  test "association filter has single param key" do
    filter = @config.filters.find { |f| f.key == :supplier_id }
    assert_equal [ "supplier_id" ], filter.param_keys
  end

  test "number_range filter has min and max param keys" do
    filter = @config.filters.find { |f| f.key == :price }
    assert_equal [ "price_min", "price_max" ], filter.param_keys
  end

  test "date_range filter has preset and from/to param keys" do
    filter = @config.filters.find { |f| f.key == :created_at }
    assert_equal [ "created_at_preset", "created_at_from", "created_at_to" ], filter.param_keys
  end

  # --- Active filters ---

  test "active_filters returns only filters with present params" do
    params = ActionController::Parameters.new(supplier_id: "1", active: "")
    active = @config.active_filters(params)
    assert_equal 1, active.size
    assert_equal :supplier_id, active.first.key
  end

  test "active_filters detects date_range by preset" do
    params = ActionController::Parameters.new(created_at_preset: "today")
    active = @config.active_filters(params)
    assert_equal 1, active.size
    assert_equal :created_at, active.first.key
  end

  # --- Apply filters ---

  test "apply_filters with association filter" do
    supplier = suppliers(:diamond_comics)
    params = ActionController::Parameters.new(supplier_id: supplier.id.to_s)
    scope = @config.apply_filters(Product.all, params)

    assert_includes scope.to_sql, "supplier_id"
  end

  test "apply_filters with boolean filter" do
    params = ActionController::Parameters.new(active: "true")

    # Build a minimal config with boolean filter for active column
    config = FilterConfig.new(:test, "/test") { |f| f.boolean :active, label: "Active" }
    scope = config.apply_filters(Customer.all, params)

    assert_includes scope.to_sql, "active"
  end

  test "apply_filters with number_range filter" do
    params = ActionController::Parameters.new(price_min: "5", price_max: "20")
    scope = @config.apply_filters(Product.all, params)
    sql = scope.to_sql

    assert_match(/price/, sql)
    assert_match(/5\.0/, sql)
    assert_match(/20\.0/, sql)
  end

  test "apply_filters ignores blank values" do
    params = ActionController::Parameters.new(supplier_id: "", active: "")
    scope = @config.apply_filters(Product.all, params)
    # No WHERE clauses should be added for blank params
    refute_match(/supplier_id/, scope.to_sql)
  end

  test "apply_filters with custom scope" do
    custom_config = FilterConfig.new(:test, "/test") do |f|
      f.association :user_id, label: "User",
                    collection: -> { User.all },
                    scope: ->(s, v) { s.where(user_type: "User", user_id: v) }
    end

    params = ActionController::Parameters.new(user_id: "42")
    scope = custom_config.apply_filters(Audited::Audit.all, params)
    sql = scope.to_sql

    assert_match(/user_type/, sql)
    assert_match(/user_id/, sql)
  end

  # --- Date presets ---

  test "resolve_date_preset returns range for today" do
    range = FilterConfig.resolve_date_preset("today")
    assert_equal 2, range.size
    assert_equal Time.zone.now.beginning_of_day.to_i, range[0].to_i
  end

  test "resolve_date_preset returns range for last_7_days" do
    range = FilterConfig.resolve_date_preset("last_7_days")
    assert_equal 7.days.ago.beginning_of_day.to_i, range[0].to_i
  end

  test "resolve_date_preset returns nil for unknown preset" do
    assert_nil FilterConfig.resolve_date_preset("unknown")
  end

  test "apply_filters with date_range preset" do
    params = ActionController::Parameters.new(created_at_preset: "today")
    scope = @config.apply_filters(Product.all, params)
    sql = scope.to_sql

    assert_match(/created_at/, sql)
    assert_match(/BETWEEN/, sql)
  end

  test "apply_filters with date_range custom from/to" do
    params = ActionController::Parameters.new(
      created_at_preset: "custom",
      created_at_from: "2025-01-01",
      created_at_to: "2025-12-31"
    )
    scope = @config.apply_filters(Product.all, params)
    sql = scope.to_sql

    assert_match(/created_at/, sql)
    assert_match(/2025-01-01/, sql)
    assert_match(/2025-12-31/, sql)
  end

  # --- JSON serialization ---

  test "filters_json returns valid JSON" do
    json = JSON.parse(@config.filters_json)
    assert_kind_of Array, json
    assert_equal 5, json.size
  end

  test "columns_json returns valid JSON" do
    json = JSON.parse(@config.columns_json)
    assert_kind_of Array, json
    assert_equal 3, json.size
    assert_equal "name", json.first["key"]
  end
end
