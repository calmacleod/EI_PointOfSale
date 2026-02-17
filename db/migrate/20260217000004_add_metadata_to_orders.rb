class AddMetadataToOrders < ActiveRecord::Migration[8.1]
  def change
    add_column :orders, :metadata, :jsonb, null: false, default: {}
    add_index :orders, :metadata, using: :gin
  end
end
