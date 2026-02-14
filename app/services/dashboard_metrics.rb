# frozen_string_literal: true

class DashboardMetrics
  # Define metrics in code. Each key maps to a block that returns the computed value
  # (numeric or nil). Values are stored in the dashboard_metrics table.
  METRIC_DEFINITIONS = {
    customers_last_7_days: -> { Customer.where("created_at >= ?", 7.days.ago).kept.count }
  }.freeze

  # Human-readable labels for profile form and dashboard.
  METRIC_LABELS = {
    customers_last_7_days: "New customers (7d)"
  }.freeze

  METRIC_DESCRIPTIONS = {
    customers_last_7_days: "Past week"
  }.freeze

  METRIC_ICONS = {
    customers_last_7_days: "M13 6a3 3 0 11-6 0 3 3 0 016 0zM18 8a2 2 0 11-4 0 2 2 0 014 0zM14 15a4 4 0 00-8 0v3h8v-3zM6 8a2 2 0 11-4 0 2 2 0 014 0zM16 18v-3a5.972 5.972 0 00-.75-2.906A3.005 3.005 0 0119 15v3h-3zM4.75 12.094A5.973 5.973 0 004 15v3H1v-3a3 3 0 013.75-2.906z"
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
