class CreateRefunds < ActiveRecord::Migration[8.1]
  def change
    create_table :refunds do |t|
      t.references :order, null: false, foreign_key: true
      t.string :refund_number, null: false
      t.integer :refund_type, null: false
      t.text :reason
      t.decimal :total, precision: 10, scale: 2, null: false
      t.references :processed_by, foreign_key: { to_table: :users }, null: false
      t.datetime :created_at, null: false
    end

    add_index :refunds, :refund_number, unique: true

    create_table :refund_lines do |t|
      t.references :refund, null: false, foreign_key: true
      t.references :order_line, null: false, foreign_key: true
      t.integer :quantity, null: false
      t.decimal :amount, precision: 10, scale: 2, null: false
      t.boolean :restock, default: false, null: false
    end
  end
end
