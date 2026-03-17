# frozen_string_literal: true

class AddSearchVectorToProducts < ActiveRecord::Migration[8.1]
  def up
    execute <<~SQL
      ALTER TABLE products
        ADD COLUMN search_vector tsvector
        GENERATED ALWAYS AS (
          to_tsvector('simple',
            coalesce(name::text, '') || ' ' ||
            coalesce(code::text, '') || ' ' ||
            coalesce(notes, '')
          )
        ) STORED;

      CREATE INDEX index_products_on_search_vector
        ON products USING GIN (search_vector)
        WHERE discarded_at IS NULL;
    SQL
  end

  def down
    execute "DROP INDEX index_products_on_search_vector"
    remove_column :products, :search_vector
  end
end
