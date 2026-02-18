# frozen_string_literal: true

class DashboardMetrics
  # Define metrics in code. Each key maps to a block that returns the computed value
  # (numeric or nil). Values are stored in the dashboard_metrics table.
  METRIC_DEFINITIONS = {
    customers_last_7_days: -> { Customer.where("created_at >= ?", 7.days.ago).kept.count },
    orders_last_7_days: -> { Order.kept.where(status: :completed).where("completed_at >= ?", 7.days.ago).count },
    revenue_last_7_days: -> { Order.kept.where(status: :completed).where("completed_at >= ?", 7.days.ago).sum(:total).to_f },
    held_orders: -> { Order.kept.held.count },
    todays_sales: -> { Order.kept.where(status: :completed).where(completed_at: Date.current.all_day).sum(:total).to_f },
    todays_transactions: -> { Order.kept.where(status: :completed).where(completed_at: Date.current.all_day).count },
    average_ticket_today: -> {
      completed_today = Order.kept.where(status: :completed).where(completed_at: Date.current.all_day)
      count = completed_today.count
      count.positive? ? (completed_today.sum(:total) / count).to_f : 0.0
    },
    low_stock_items: -> { Product.kept.where("stock_level <= reorder_level").where("reorder_level > 0").count }
  }.freeze

  # Human-readable labels for profile form and dashboard.
  METRIC_LABELS = {
    customers_last_7_days: "New customers (7d)",
    orders_last_7_days: "Orders (7d)",
    revenue_last_7_days: "Revenue (7d)",
    held_orders: "Held orders",
    todays_sales: "Today's sales",
    todays_transactions: "Transactions",
    average_ticket_today: "Average ticket",
    low_stock_items: "Low stock"
  }.freeze

  METRIC_DESCRIPTIONS = {
    customers_last_7_days: "Past week",
    orders_last_7_days: "Completed orders",
    revenue_last_7_days: "Completed orders",
    held_orders: "Awaiting action",
    todays_sales: "Completed today",
    todays_transactions: "Completed today",
    average_ticket_today: "Per transaction today",
    low_stock_items: "Items need attention"
  }.freeze

  METRIC_ICONS = {
    customers_last_7_days: "M13 6a3 3 0 11-6 0 3 3 0 016 0zM18 8a2 2 0 11-4 0 2 2 0 014 0zM14 15a4 4 0 00-8 0v3h8v-3zM6 8a2 2 0 11-4 0 2 2 0 014 0zM16 18v-3a5.972 5.972 0 00-.75-2.906A3.005 3.005 0 0119 15v3h-3zM4.75 12.094A5.973 5.973 0 004 15v3H1v-3a3 3 0 013.75-2.906z",
    orders_last_7_days: "M4 4a2 2 0 012-2h8a2 2 0 012 2v12a2 2 0 01-2 2H6a2 2 0 01-2-2V4zm3 3a1 1 0 000 2h6a1 1 0 100-2H7zm0 4a1 1 0 000 2h6a1 1 0 100-2H7z",
    revenue_last_7_days: "M10 18a8 8 0 100-16 8 8 0 000 16zm1-12a1 1 0 10-2 0v1H8a1 1 0 000 2h1v1H8a1 1 0 000 2h1v1a1 1 0 102 0v-1h1a1 1 0 100-2h-1V9h1a1 1 0 100-2h-1V6z",
    held_orders: "M10 18a8 8 0 100-16 8 8 0 000 16zm1-12a1 1 0 10-2 0v4a1 1 0 00.293.707l2.828 2.829a1 1 0 101.415-1.415L11 9.586V6z",
    todays_sales: "M10 18a8 8 0 100-16 8 8 0 000 16zm1-12a1 1 0 10-2 0v1H8a1 1 0 000 2h1v1H8a1 1 0 000 2h1v1a1 1 0 102 0v-1h1a1 1 0 100-2h-1V9h1a1 1 0 100-2h-1V6z",
    todays_transactions: "M4 4a2 2 0 012-2h8a2 2 0 012 2v12a2 2 0 01-2 2H6a2 2 0 01-2-2V4zm3 3a1 1 0 000 2h6a1 1 0 100-2H7zm0 4a1 1 0 000 2h6a1 1 0 100-2H7z",
    average_ticket_today: "M10 2a1 1 0 011 1v1.07A7 7 0 0117 11a7 7 0 11-7-6.93V3a1 1 0 011-1zm0 5a5 5 0 100 10 5 5 0 000-10z",
    low_stock_items: "M8.257 3.099c.765-1.36 2.721-1.36 3.486 0l6.516 11.59c.75 1.334-.214 2.99-1.743 2.99H3.484c-1.53 0-2.493-1.656-1.743-2.99l6.516-11.59zM11 14a1 1 0 10-2 0 1 1 0 002 0zm-1-8a1 1 0 00-1 1v4a1 1 0 102 0V7a1 1 0 00-1-1z"
  }.freeze

  # Route paths for metrics that should link to relevant pages
  METRIC_LINKS = {
    customers_last_7_days: :customers_path,
    orders_last_7_days: :orders_path,
    revenue_last_7_days: :orders_path,
    held_orders: :held_orders_path,
    todays_sales: :orders_path,
    todays_transactions: :orders_path,
    average_ticket_today: :orders_path,
    low_stock_items: :products_path
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

    def link_path_for(key)
      METRIC_LINKS[key.to_sym]
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
