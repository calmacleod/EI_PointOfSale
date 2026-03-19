class CreateRestocks < ActiveRecord::Migration[8.1]
  def change
    create_table :restocks do |t|
      t.references :product, null: false, foreign_key: true
      t.references :user, null: false, foreign_key: true
      t.integer :quantity, null: false
      t.integer :stock_level_after, null: false
      t.text :notes
      t.timestamps
    end
    add_index :restocks, [ :product_id, :created_at ]
  end
end
