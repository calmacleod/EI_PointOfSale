class CreateReports < ActiveRecord::Migration[8.1]
  def change
    create_table :reports do |t|
      t.string :report_type, null: false
      t.string :title, null: false
      t.string :status, null: false, default: "pending"
      t.jsonb :parameters, null: false, default: {}
      t.jsonb :result_data
      t.text :error_message
      t.references :generated_by, null: false, foreign_key: { to_table: :users }
      t.datetime :started_at
      t.datetime :completed_at

      t.timestamps
    end

    add_index :reports, :report_type
    add_index :reports, :status
    add_index :reports, :created_at
  end
end
