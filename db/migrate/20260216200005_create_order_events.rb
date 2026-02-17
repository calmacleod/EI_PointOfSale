class CreateOrderEvents < ActiveRecord::Migration[8.1]
  def change
    create_table :order_events do |t|
      t.references :order, null: false, foreign_key: true
      t.string :event_type, null: false
      t.jsonb :data, default: {}
      t.references :actor, foreign_key: { to_table: :users }, null: false
      t.datetime :created_at, null: false
    end

    add_index :order_events, [ :order_id, :created_at ]
  end
end
