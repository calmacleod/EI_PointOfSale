class CreateDiscounts < ActiveRecord::Migration[8.1]
  def change
    create_table :discounts do |t|
      t.string :name, null: false
      t.text :description
      t.integer :discount_type, null: false
      t.decimal :value, precision: 10, scale: 2, null: false
      t.boolean :active, null: false, default: true
      t.datetime :starts_at
      t.datetime :ends_at
      t.boolean :applies_to_all, null: false, default: false
      t.datetime :discarded_at

      t.timestamps
    end

    add_index :discounts, :discarded_at
    add_index :discounts, :active
  end
end
