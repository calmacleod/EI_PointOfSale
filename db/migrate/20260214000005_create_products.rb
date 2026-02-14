class CreateProducts < ActiveRecord::Migration[8.1]
  def change
    create_table :products do |t|
      t.string :name, null: false
      t.string :product_url
      t.references :tax_code, foreign_key: true
      t.references :supplier, foreign_key: true
      t.references :added_by, foreign_key: { to_table: :users }
      t.jsonb :metadata, default: {}
      t.datetime :discarded_at, index: true
      t.timestamps
    end
  end
end
