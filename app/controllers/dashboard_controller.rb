class DashboardController < ApplicationController
  def index
    visible_keys = Current.user&.visible_dashboard_metric_keys || DashboardMetrics.available_keys
    @visible_metrics = visible_keys.map do |key|
      {
        key: key,
        value: DashboardMetrics[key],
        label: DashboardMetrics.label_for(key),
        description: DashboardMetrics.description_for(key),
        icon: DashboardMetrics.icon_path_for(key)
      }
    end

    today = Date.current.all_day
    completed_today = Order.kept.where(status: :completed).where(completed_at: today)
    @todays_sales = completed_today.sum(:total)
    @todays_transactions = completed_today.count
    @average_ticket = @todays_transactions > 0 ? @todays_sales / @todays_transactions : 0

    yesterday = Date.yesterday.all_day
    @yesterdays_sales = Order.kept.where(status: :completed).where(completed_at: yesterday).sum(:total)

    @low_stock_count = Product.kept.where("stock_level <= reorder_level").where("reorder_level > 0").count

    @recent_orders = Order.kept.recent.limit(10)

    if Current.user
      @my_tasks = StoreTask.where.not(status: :done)
                           .where(assigned_to: Current.user)
                           .order(Arel.sql("CASE WHEN due_date < #{ActiveRecord::Base.connection.quote(Date.current)} THEN 0 ELSE 1 END, due_date ASC NULLS LAST"))
    end
  end
end
