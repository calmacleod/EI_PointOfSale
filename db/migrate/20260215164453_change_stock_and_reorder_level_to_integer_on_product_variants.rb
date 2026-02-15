class ChangeStockAndReorderLevelToIntegerOnProductVariants < ActiveRecord::Migration[8.1]
  def up
    change_column :product_variants, :stock_level, :integer, default: 0, null: false
    change_column :product_variants, :reorder_level, :integer, default: 0, null: false
  end

  def down
    change_column :product_variants, :stock_level, :decimal, precision: 12, scale: 4, default: 0.0
    change_column :product_variants, :reorder_level, :decimal, precision: 12, scale: 4, default: 0.0
  end
end
