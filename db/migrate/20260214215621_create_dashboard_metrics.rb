class CreateDashboardMetrics < ActiveRecord::Migration[8.1]
  def change
    create_table :dashboard_metrics do |t|
      t.string :key, null: false
      t.decimal :value, precision: 20, scale: 4
      t.datetime :computed_at, null: false

      t.timestamps
    end
    add_index :dashboard_metrics, :key, unique: true
  end
end
