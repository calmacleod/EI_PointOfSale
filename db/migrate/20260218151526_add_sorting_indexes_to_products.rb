# frozen_string_literal: true

class AddSortingIndexesToProducts < ActiveRecord::Migration[8.1]
  def change
    # Composite index for sorting kept products by name
    # Supports queries like: Product.kept.order(:name).limit(25)
    add_index :products, [ :discarded_at, :name ],
              name: "index_products_on_discarded_at_and_name"

    # Composite index for sorting kept products by code
    # Supports queries like: Product.kept.order(:code).limit(25)
    add_index :products, [ :discarded_at, :code ],
              name: "index_products_on_discarded_at_and_code"
  end
end
