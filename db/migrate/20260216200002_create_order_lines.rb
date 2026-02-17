class CreateOrderLines < ActiveRecord::Migration[8.1]
  def change
    create_table :order_lines do |t|
      t.references :order, null: false, foreign_key: true
      t.references :sellable, polymorphic: true, null: false
      t.string :code
      t.string :name, null: false
      t.integer :quantity, null: false, default: 1
      t.decimal :unit_price, precision: 10, scale: 2, null: false
      t.decimal :discount_amount, precision: 10, scale: 2, default: 0
      t.decimal :tax_rate, precision: 5, scale: 4, default: 0
      t.decimal :tax_amount, precision: 10, scale: 2, default: 0
      t.decimal :line_total, precision: 10, scale: 2, null: false
      t.references :tax_code, foreign_key: true, null: true
      t.integer :position, default: 0

      t.timestamps
    end

    add_index :order_lines, [ :order_id, :position ]
  end
end
