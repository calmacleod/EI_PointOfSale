class AddExclusionTypeToDiscountItems < ActiveRecord::Migration[8.1]
  def change
    add_column :discount_items, :exclusion_type, :integer, default: 0, null: false
    add_index :discount_items, [ :discount_id, :exclusion_type ], name: "index_discount_items_on_discount_and_exclusion"
    add_index :discount_items, [ :exclusion_type ], name: "index_discount_items_on_exclusion_type"
  end
end
