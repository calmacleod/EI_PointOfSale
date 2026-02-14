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
  end
end
