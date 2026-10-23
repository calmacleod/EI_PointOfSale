# frozen_string_literal: true

class IndexCatalogSyncCursors < ActiveRecord::Migration[8.1]
  disable_ddl_transaction!

  def change
    # Include discarded rows: delta pages carry deletion IDs as well as records.
    %i[products services customers tax_codes].each do |table|
      add_index table, [ :updated_at, :id ], algorithm: :concurrently
    end
  end
end
