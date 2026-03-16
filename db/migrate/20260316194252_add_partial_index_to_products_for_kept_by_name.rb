# frozen_string_literal: true

class AddPartialIndexToProductsForKeptByName < ActiveRecord::Migration[8.1]
  def change
    # Partial index covering only non-discarded products.
    # Smaller than the full composite index and gives the planner certainty
    # it matches `WHERE discarded_at IS NULL`, enabling index scans for both
    # ORDER BY name LIMIT n and COUNT(*) on the kept scope.
    add_index :products, :name,
              where: "discarded_at IS NULL",
              name: "index_products_on_name_kept"
  end
end
