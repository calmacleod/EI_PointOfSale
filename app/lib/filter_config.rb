# frozen_string_literal: true

# Declarative configuration for filters and columns on index pages.
#
# Usage in a controller:
#
#   @filter_config = FilterConfig.new(:products, products_path) do |f|
#     f.association :supplier_id, label: "Supplier", collection: -> { Supplier.kept.order(:name) }
#     f.boolean     :sync_to_shopify, label: "Shopify Sync"
#     f.number_range :selling_price,  label: "Price"
#     f.date_range   :created_at,     label: "Created"
#
#     f.column :code, label: "Code", default: true, sortable: true
#     f.column :name, label: "Product", default: true, sortable: true
#   end
#
class FilterConfig
  FilterDefinition = Data.define(:key, :type, :label, :options) do
    def param_keys
      case type
      when :number_range
        [ "#{key}_min", "#{key}_max" ]
      when :date_range
        [ "#{key}_preset", "#{key}_from", "#{key}_to" ]
      else
        [ key.to_s ]
      end
    end

    def js_param_keys
      case type
      when :multi_select
        [ "#{key}[]" ]
      else
        param_keys
      end
    end
  end

  ColumnDefinition = Data.define(:key, :label, :default, :sortable, :width)

  DATE_PRESETS = {
    "today"       => -> { [ Time.zone.now.beginning_of_day, Time.zone.now.end_of_day ] },
    "yesterday"   => -> { [ 1.day.ago.beginning_of_day, 1.day.ago.end_of_day ] },
    "last_7_days" => -> { [ 7.days.ago.beginning_of_day, Time.zone.now.end_of_day ] },
    "last_30_days" => -> { [ 30.days.ago.beginning_of_day, Time.zone.now.end_of_day ] },
    "this_month"  => -> { [ Time.zone.now.beginning_of_month, Time.zone.now.end_of_day ] },
    "last_month"  => -> { [ 1.month.ago.beginning_of_month, 1.month.ago.end_of_month ] },
    "this_year"   => -> { [ Time.zone.now.beginning_of_year, Time.zone.now.end_of_day ] }
  }.freeze

  DATE_PRESET_LABELS = [
    [ "Today", "today" ],
    [ "Yesterday", "yesterday" ],
    [ "Last 7 days", "last_7_days" ],
    [ "Last 30 days", "last_30_days" ],
    [ "This month", "this_month" ],
    [ "Last month", "last_month" ],
    [ "This year", "this_year" ],
    [ "Custom", "custom" ]
  ].freeze

  attr_reader :resource_name, :search_path, :filters, :columns,
              :sort_default, :sort_default_direction, :search_scope, :search_placeholder

  def initialize(resource_name, search_path, sort_default: "created_at",
                 sort_default_direction: "desc", search: :search,
                 search_placeholder: nil)
    @resource_name = resource_name.to_s
    @search_path = search_path
    @sort_default = sort_default.to_s
    @sort_default_direction = sort_default_direction.to_s
    @search_scope = search
    @search_placeholder = search_placeholder || "Search #{@resource_name.tr('_', ' ')}..."
    @filters = []
    @columns = []
    yield self if block_given?
  end

  # --- Filter DSL methods ---

  def association(key, label:, collection:, display: :name, scope: nil)
    @filters << FilterDefinition.new(
      key: key.to_sym,
      type: :association,
      label: label,
      options: { collection: collection, display: display, scope: scope }
    )
  end

  def select(key, label:, options:, scope: nil)
    @filters << FilterDefinition.new(
      key: key.to_sym,
      type: :select,
      label: label,
      options: { choices: options, scope: scope }
    )
  end

  def boolean(key, label:, scope: nil)
    @filters << FilterDefinition.new(
      key: key.to_sym,
      type: :boolean,
      label: label,
      options: { scope: scope }
    )
  end

  def number_range(key, label:)
    @filters << FilterDefinition.new(
      key: key.to_sym,
      type: :number_range,
      label: label,
      options: {}
    )
  end

  def date_range(key, label:)
    @filters << FilterDefinition.new(
      key: key.to_sym,
      type: :date_range,
      label: label,
      options: {}
    )
  end

  def multi_select(key, label:, collection:, display: :name, scope: nil)
    @filters << FilterDefinition.new(
      key: key.to_sym,
      type: :multi_select,
      label: label,
      options: { collection: collection, display: display, scope: scope }
    )
  end

  # --- Column DSL ---

  def column(key, label:, default: true, sortable: false, width: nil)
    @columns << ColumnDefinition.new(
      key: key.to_sym,
      label: label,
      default: default,
      sortable: sortable,
      width: width
    )
  end

  # --- Query methods ---

  def sortable_columns
    @columns.select(&:sortable).map { |c| c.key.to_s }
  end

  def default_columns
    @columns.select(&:default).map { |c| c.key.to_s }
  end

  def all_filter_param_keys
    @filters.flat_map(&:param_keys) + [ "q" ]
  end

  def active_filters(params)
    @filters.select { |f| filter_active?(f, params) }
  end

  # --- Filter application ---

  def apply_filters(scope, params)
    @filters.each do |filter|
      scope = apply_single_filter(scope, filter, params)
    end
    scope
  end

  # --- Date preset resolution ---

  def self.resolve_date_preset(preset)
    resolver = DATE_PRESETS[preset.to_s]
    resolver&.call
  end

  # --- JSON for Stimulus ---

  def filters_json
    @filters.map { |f|
      base = { key: f.key, type: f.type, label: f.label, paramKeys: f.js_param_keys }
      case f.type
      when :association, :multi_select
        items = f.options[:collection].call
        display = f.options[:display] || :name
        base[:choices] = items.map { |item| { value: item.id.to_s, label: item.public_send(display) } }
      when :select
        base[:choices] = f.options[:choices].map { |label, value| { value: value.to_s, label: label } }
      when :boolean
        base[:choices] = [ { value: "true", label: "Yes" }, { value: "false", label: "No" } ]
      when :date_range
        base[:presets] = DATE_PRESET_LABELS.map { |label, value| { value: value, label: label } }
      end
      base
    }.to_json
  end

  def columns_json
    @columns.map { |c|
      hash = { key: c.key, label: c.label, default: c.default, sortable: c.sortable }
      hash[:width] = c.width if c.width
      hash
    }.to_json
  end

  private

    def filter_active?(filter, params)
      filter.param_keys.any? { |k|
        value = params[k]
        if value.is_a?(Array)
          value.any?(&:present?)
        else
          value.present?
        end
      }
    end

    def apply_single_filter(scope, filter, params)
      case filter.type
      when :multi_select
        apply_multi_select_filter(scope, filter, params)
      else
        # Custom scope overrides default behavior for equality/boolean filters
        if filter.options[:scope] && params[filter.key.to_s].present?
          return filter.options[:scope].call(scope, params[filter.key.to_s])
        end

        case filter.type
        when :association, :select
          apply_equality_filter(scope, filter, params)
        when :boolean
          apply_boolean_filter(scope, filter, params)
        when :number_range
          apply_number_range_filter(scope, filter, params)
        when :date_range
          apply_date_range_filter(scope, filter, params)
        else
          scope
        end
      end
    end

    def apply_multi_select_filter(scope, filter, params)
      values = Array(params[filter.key.to_s]).select(&:present?)
      return scope if values.empty?

      if filter.options[:scope]
        filter.options[:scope].call(scope, values)
      else
        scope.where(filter.key => values)
      end
    end

    def apply_equality_filter(scope, filter, params)
      value = params[filter.key.to_s]
      return scope if value.blank?

      scope.where(filter.key => value)
    end

    def apply_boolean_filter(scope, filter, params)
      value = params[filter.key.to_s]
      return scope if value.blank?

      scope.where(filter.key => ActiveModel::Type::Boolean.new.cast(value))
    end

    def apply_number_range_filter(scope, filter, params)
      min_val = params["#{filter.key}_min"]
      max_val = params["#{filter.key}_max"]

      scope = scope.where(filter.key => min_val.to_f..) if min_val.present?
      scope = scope.where(filter.key => ..max_val.to_f) if max_val.present?
      scope
    end

    def apply_date_range_filter(scope, filter, params)
      preset = params["#{filter.key}_preset"]

      if preset.present? && preset != "custom"
        range = self.class.resolve_date_preset(preset)
        scope = scope.where(filter.key => range[0]..range[1]) if range
      else
        from_val = parse_date_beginning(params["#{filter.key}_from"])
        to_val = parse_date_end(params["#{filter.key}_to"])
        scope = scope.where(filter.key => from_val..) if from_val
        scope = scope.where(filter.key => ..to_val) if to_val
      end
      scope
    end

    def parse_date_beginning(value)
      return nil if value.blank?

      Time.zone.parse(value.to_s).beginning_of_day
    rescue ArgumentError
      nil
    end

    def parse_date_end(value)
      return nil if value.blank?

      Time.zone.parse(value.to_s).end_of_day
    rescue ArgumentError
      nil
    end
end
