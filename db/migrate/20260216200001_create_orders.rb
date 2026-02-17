class CreateOrders < ActiveRecord::Migration[8.1]
  def change
    create_table :orders do |t|
      t.string :number, null: false
      t.references :customer, foreign_key: true, null: true
      t.references :created_by, foreign_key: { to_table: :users }, null: false
      t.references :cash_drawer_session, foreign_key: true, null: true
      t.integer :status, null: false, default: 0
      t.decimal :subtotal, precision: 10, scale: 2, default: 0
      t.decimal :discount_total, precision: 10, scale: 2, default: 0
      t.decimal :tax_total, precision: 10, scale: 2, default: 0
      t.decimal :total, precision: 10, scale: 2, default: 0
      t.boolean :tax_exempt, default: false, null: false
      t.string :tax_exempt_number
      t.text :notes
      t.datetime :held_at
      t.datetime :completed_at
      t.datetime :discarded_at

      t.timestamps
    end

    add_index :orders, :number, unique: true
    add_index :orders, :status
    add_index :orders, :completed_at
    add_index :orders, :discarded_at
  end
end
