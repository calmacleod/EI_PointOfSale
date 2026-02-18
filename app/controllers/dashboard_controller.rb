class DashboardController < ApplicationController
  def index
    visible_keys = Current.user&.visible_dashboard_metric_keys || DashboardMetrics.available_keys
    @visible_metrics = visible_keys.map do |key|
      {
        key: key,
        value: DashboardMetrics[key],
        label: DashboardMetrics.label_for(key),
        description: DashboardMetrics.description_for(key),
        icon: DashboardMetrics.icon_path_for(key),
        format: metric_format_for(key),
        link_path: DashboardMetrics.link_path_for(key),
        computed_at: DashboardMetrics.computed_at(key)
      }
    end

    @metrics_last_updated = @visible_metrics.map { |m| m[:computed_at] }.compact.max

    @recent_orders = Order.kept.recent.limit(5)

    if Current.user
      @my_tasks = StoreTask.where.not(status: :done)
                           .where(assigned_to: Current.user)
                           .order(Arel.sql("CASE WHEN due_date < #{ActiveRecord::Base.connection.quote(Date.current)} THEN 0 ELSE 1 END, due_date ASC NULLS LAST"))
    end
  end

  private

    def metric_format_for(key)
      case key.to_sym
      when :todays_sales, :revenue_last_7_days, :average_ticket_today
        :currency
      when :customers_last_7_days, :orders_last_7_days, :held_orders, :todays_transactions, :low_stock_items
        :integer
      else
        :integer
      end
    end
end
