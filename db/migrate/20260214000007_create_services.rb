class CreateServices < ActiveRecord::Migration[8.1]
  def change
    create_table :services do |t|
      t.string :name, null: false
      t.string :code, index: { unique: true }
      t.text :description
      t.decimal :price, precision: 10, scale: 2, null: false
      t.references :tax_code, foreign_key: true
      t.references :added_by, foreign_key: { to_table: :users }
      t.jsonb :metadata, default: {}
      t.datetime :discarded_at, index: true
      t.timestamps
    end
  end
end
