# frozen_string_literal: true

class IndexRegisterLookups < ActiveRecord::Migration[8.1]
  disable_ddl_transaction!

  def up
    %i[products services].each do |table|
      # find_by_exact_code preserves first-by-id behavior for case variants.
      add_index table, "lower(code), id", name: "index_#{table}_on_kept_lower_code",
        where: "discarded_at IS NULL", algorithm: :concurrently, if_not_exists: true
    end

    add_index :services, "to_tsvector('simple', coalesce(name, '') || ' ' || coalesce(code, '') || ' ' || coalesce(description, ''))",
      name: "index_services_on_register_search", using: :gin, where: "discarded_at IS NULL", algorithm: :concurrently, if_not_exists: true
    add_index :customers, "to_tsvector('simple', coalesce(name, '') || ' ' || coalesce(member_number, '') || ' ' || coalesce(email, '') || ' ' || coalesce(phone, '') || ' ' || regexp_replace(coalesce(phone, ''), '[^0-9]', '', 'g'))",
      name: "index_customers_on_register_search", using: :gin, where: "discarded_at IS NULL", algorithm: :concurrently, if_not_exists: true
    add_index :customers, "lower(name) gin_trgm_ops", name: "index_customers_on_name_trigram",
      using: :gin, where: "discarded_at IS NULL", algorithm: :concurrently, if_not_exists: true
  end

  def down
    remove_index :customers, name: "index_customers_on_name_trigram", algorithm: :concurrently
    remove_index :customers, name: "index_customers_on_register_search", algorithm: :concurrently
    remove_index :services, name: "index_services_on_register_search", algorithm: :concurrently
    %i[products services].each do |table|
      remove_index table, name: "index_#{table}_on_kept_lower_code", algorithm: :concurrently
    end
  end
end
