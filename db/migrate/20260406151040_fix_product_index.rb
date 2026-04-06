class FixProductIndex < ActiveRecord::Migration[8.1]
  def change
    add_index :products, :id, where: "discarded_at IS NULL", name: "index_products_on_discarded_at_null_test"
  end
end
