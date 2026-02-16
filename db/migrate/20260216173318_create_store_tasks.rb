class CreateStoreTasks < ActiveRecord::Migration[8.1]
  def change
    create_table :store_tasks do |t|
      t.string :title, null: false
      t.text :body
      t.integer :status, null: false, default: 0
      t.references :assigned_to, null: true, foreign_key: { to_table: :users }
      t.date :due_date

      t.timestamps
    end

    add_index :store_tasks, :status
    add_index :store_tasks, :due_date
  end
end
