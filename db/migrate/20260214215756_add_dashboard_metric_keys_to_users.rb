class AddDashboardMetricKeysToUsers < ActiveRecord::Migration[8.1]
  def change
    add_column :users, :dashboard_metric_keys, :string, array: true, default: []
  end
end
