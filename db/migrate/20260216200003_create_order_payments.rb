class CreateOrderPayments < ActiveRecord::Migration[8.1]
  def change
    create_table :order_payments do |t|
      t.references :order, null: false, foreign_key: true
      t.integer :payment_method, null: false
      t.decimal :amount, precision: 10, scale: 2, null: false
      t.decimal :amount_tendered, precision: 10, scale: 2
      t.decimal :change_given, precision: 10, scale: 2
      t.string :reference
      t.references :received_by, foreign_key: { to_table: :users }, null: true

      t.timestamps
    end
  end
end
