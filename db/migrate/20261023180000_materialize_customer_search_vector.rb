# frozen_string_literal: true

class MaterializeCustomerSearchVector < ActiveRecord::Migration[8.1]
  disable_ddl_transaction!

  VECTOR = "to_tsvector('simple', coalesce(name, '') || ' ' || coalesce(member_number, '') || ' ' || coalesce(email, '') || ' ' || coalesce(phone, '') || ' ' || regexp_replace(coalesce(phone, ''), '[^0-9]', '', 'g'))"

  def up
    # PostgreSQL rewrites the table to populate this stored column. Schedule this
    # step outside checkout hours; only the index builds are concurrent.
    add_column :customers, :search_vector, :virtual, type: :tsvector, as: VECTOR, stored: true
    add_index :customers, :search_vector, name: "index_customers_on_search_vector",
      using: :gin, where: "discarded_at IS NULL", algorithm: :concurrently
    remove_index :customers, name: "index_customers_on_register_search", algorithm: :concurrently
  end

  def down
    add_index :customers, VECTOR, name: "index_customers_on_register_search",
      using: :gin, where: "discarded_at IS NULL", algorithm: :concurrently
    remove_index :customers, name: "index_customers_on_search_vector", algorithm: :concurrently
    remove_column :customers, :search_vector
  end
end
