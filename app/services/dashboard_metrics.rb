# frozen_string_literal: true

class DashboardMetrics
  # Define metrics in code. Each key maps to a block that returns the computed value
  # (numeric or nil). Values are stored in the dashboard_metrics table.
  METRIC_DEFINITIONS = {
    customers_last_7_days: -> { Customer.where("created_at >= ?", 7.days.ago).kept.count },
    orders_last_7_days: -> { Order.kept.where(status: :completed).where("completed_at >= ?", 7.days.ago).count },
    revenue_last_7_days: -> { Order.kept.where(status: :completed).where("completed_at >= ?", 7.days.ago).sum(:total).to_f },
    held_orders: -> { Order.kept.held.count }
  }.freeze

  # Human-readable labels for profile form and dashboard.
  METRIC_LABELS = {
    customers_last_7_days: "New customers (7d)",
    orders_last_7_days: "Orders (7d)",
    revenue_last_7_days: "Revenue (7d)",
    held_orders: "Held orders"
  }.freeze

  METRIC_DESCRIPTIONS = {
    customers_last_7_days: "Past week",
    orders_last_7_days: "Completed orders",
    revenue_last_7_days: "Completed orders",
    held_orders: "Awaiting action"
  }.freeze

  METRIC_ICONS = {
    customers_last_7_days: "M13 6a3 3 0 11-6 0 3 3 0 016 0zM18 8a2 2 0 11-4 0 2 2 0 014 0zM14 15a4 4 0 00-8 0v3h8v-3zM6 8a2 2 0 11-4 0 2 2 0 014 0zM16 18v-3a5.972 5.972 0 00-.75-2.906A3.005 3.005 0 0119 15v3h-3zM4.75 12.094A5.973 5.973 0 004 15v3H1v-3a3 3 0 013.75-2.906z",
    orders_last_7_days: "M4 4a2 2 0 012-2h8a2 2 0 012 2v12a2 2 0 01-2 2H6a2 2 0 01-2-2V4zm3 3a1 1 0 000 2h6a1 1 0 100-2H7zm0 4a1 1 0 000 2h6a1 1 0 100-2H7z",
    revenue_last_7_days: "M10 18a8 8 0 100-16 8 8 0 000 16zm1-12a1 1 0 10-2 0v1H8a1 1 0 000 2h1v1H8a1 1 0 000 2h1v1a1 1 0 102 0v-1h1a1 1 0 100-2h-1V9h1a1 1 0 100-2h-1V6z",
    held_orders: "M10 18a8 8 0 100-16 8 8 0 000 16zm1-12a1 1 0 10-2 0v4a1 1 0 00.293.707l2.828 2.829a1 1 0 101.415-1.415L11 9.586V6z"
  }.freeze

  class << self
    def available_keys
      METRIC_DEFINITIONS.keys.map(&:to_s)
    end

    def label_for(key)
      METRIC_LABELS[key.to_sym] || key.to_s.humanize
    end

    def description_for(key)
      METRIC_DESCRIPTIONS[key.to_sym] || ""
    end

    def icon_path_for(key)
      METRIC_ICONS[key.to_sym]
    end

    def refresh!
      METRIC_DEFINITIONS.each do |key, block|
        value = block.call
        record = DashboardMetric.find_or_initialize_by(key: key.to_s)
        record.assign_attributes(value: value, computed_at: Time.current)
        record.save!
      end
    end

    def [](key)
      record = DashboardMetric.find_by(key: key.to_s)
      return compute_fallback(key.to_sym) unless record

      record.value
    end

    def computed_at(key)
      DashboardMetric.find_by(key: key.to_s)&.computed_at
    end

    private

      def compute_fallback(key)
        return nil unless METRIC_DEFINITIONS.key?(key)

        METRIC_DEFINITIONS[key].call
      end
  end
end
