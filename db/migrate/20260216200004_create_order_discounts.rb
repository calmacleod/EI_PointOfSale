class CreateOrderDiscounts < ActiveRecord::Migration[8.1]
  def change
    create_table :order_discounts do |t|
      t.references :order, null: false, foreign_key: true
      t.string :name, null: false
      t.integer :discount_type, null: false
      t.decimal :value, precision: 10, scale: 2, null: false
      t.integer :scope, null: false, default: 0
      t.decimal :calculated_amount, precision: 10, scale: 2, default: 0
      t.references :applied_by, foreign_key: { to_table: :users }, null: true

      t.timestamps
    end

    create_table :order_discount_items do |t|
      t.references :order_discount, null: false, foreign_key: true
      t.references :order_line, null: false, foreign_key: true

      t.timestamps
    end

    add_index :order_discount_items, [ :order_discount_id, :order_line_id ],
              unique: true, name: "idx_discount_items_uniqueness"
  end
end
