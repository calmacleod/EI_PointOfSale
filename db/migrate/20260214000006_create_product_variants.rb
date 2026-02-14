class CreateProductVariants < ActiveRecord::Migration[8.1]
  def change
    create_table :product_variants do |t|
      t.references :product, null: false, foreign_key: true
      t.string :code, null: false, index: { unique: true }
      t.string :name
      t.jsonb :option_values, default: {}
      t.decimal :selling_price, precision: 10, scale: 2
      t.decimal :purchase_price, precision: 10, scale: 2
      t.decimal :stock_level, precision: 12, scale: 4, default: 0
      t.decimal :reorder_level, precision: 12, scale: 4, default: 0
      t.decimal :order_quantity, precision: 12, scale: 4
      t.decimal :unit_cost, precision: 10, scale: 2
      t.decimal :items_per_unit, precision: 12, scale: 4
      t.string :supplier_reference
      t.text :notes
      t.references :supplier, foreign_key: true
      t.datetime :discarded_at, index: true
      t.timestamps
    end
  end
end
