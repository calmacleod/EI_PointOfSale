class CreateSavedQueries < ActiveRecord::Migration[8.1]
  def change
    create_table :saved_queries do |t|
      t.string :name, null: false
      t.string :resource_type, null: false
      t.jsonb :query_params, null: false, default: {}
      t.references :user, null: false, foreign_key: true

      t.timestamps
    end

    add_index :saved_queries, [ :user_id, :resource_type ]
  end
end
