class AddSalesCountToProductsAndServices < ActiveRecord::Migration[8.1]
  def change
    add_column :products, :sales_count, :integer, default: 0, null: false
    add_column :services, :sales_count, :integer, default: 0, null: false

    add_index :products, :sales_count, order: :desc
    add_index :services, :sales_count, order: :desc
  end
end
