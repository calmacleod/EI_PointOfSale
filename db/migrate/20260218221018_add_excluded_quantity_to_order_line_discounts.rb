# frozen_string_literal: true

class AddExcludedQuantityToOrderLineDiscounts < ActiveRecord::Migration[8.1]
  def change
    add_column :order_line_discounts, :excluded_quantity, :integer, default: 0, null: false
    add_index :order_line_discounts, :excluded_quantity, name: "index_order_line_discounts_on_excluded_quantity"
  end
end
