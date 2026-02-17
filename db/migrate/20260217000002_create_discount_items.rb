class CreateDiscountItems < ActiveRecord::Migration[8.1]
  def change
    create_table :discount_items do |t|
      t.references :discount, null: false, foreign_key: true
      t.string :discountable_type, null: false
      t.bigint :discountable_id, null: false

      t.timestamps
    end

    add_index :discount_items, [ :discountable_type, :discountable_id ],
              name: "index_discount_items_on_discountable"
    add_index :discount_items, [ :discount_id, :discountable_type, :discountable_id ],
              unique: true, name: "index_discount_items_uniqueness"
  end
end
