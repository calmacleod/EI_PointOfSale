# frozen_string_literal: true

class CreateOrderLineDiscounts < ActiveRecord::Migration[8.1]
  def up
    create_table :order_line_discounts do |t|
      t.references :order_line, null: false, foreign_key: true
      t.references :source_discount, null: true, foreign_key: { to_table: :discounts }

      t.string :name, null: false
      t.integer :discount_type, null: false
      t.decimal :value, precision: 10, scale: 2, null: false
      t.decimal :calculated_amount, precision: 10, scale: 2, default: 0
      t.boolean :auto_applied, default: false, null: false
      t.datetime :excluded_at

      t.timestamps
    end

    # Rails automatically adds index on order_line_id from t.references
    # We add a unique partial index for the auto-applied discounts
    add_index :order_line_discounts, [ :order_line_id, :source_discount_id ],
              unique: true,
              where: "source_discount_id IS NOT NULL",
              name: "idx_line_discounts_uniq_auto"

    # Drop the old join table (data migration handled separately)
    drop_table :order_discount_items if table_exists?(:order_discount_items)
  end

  def down
    # Recreate the old join table
    create_table :order_discount_items do |t|
      t.bigint :order_discount_id, null: false
      t.bigint :order_line_id, null: false
      t.timestamps
    end

    add_index :order_discount_items, [ :order_discount_id, :order_line_id ],
              unique: true,
              name: "idx_discount_items_uniqueness"
    add_index :order_discount_items, :order_discount_id,
              name: "index_order_discount_items_on_order_discount_id"
    add_index :order_discount_items, :order_line_id,
              name: "index_order_discount_items_on_order_line_id"

    # Migrate data back (best effort - loses excluded_at info)
    OrderLineDiscount.where(excluded_at: nil).find_each do |line_discount|
      next unless line_discount.source_discount_id.present?

      order_discount = OrderDiscount.find_by(
        order_id: line_discount.order_line.order_id,
        discount_id: line_discount.source_discount_id
      )

      if order_discount
        OrderDiscountItem.create!(
          order_discount: order_discount,
          order_line_id: line_discount.order_line_id
        )
      end
    end

    drop_table :order_line_discounts
  end
end
