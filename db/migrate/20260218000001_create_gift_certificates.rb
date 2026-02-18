# frozen_string_literal: true

class CreateGiftCertificates < ActiveRecord::Migration[8.1]
  def change
    create_table :gift_certificates do |t|
      t.string  :code,              null: false
      t.integer :status,            null: false, default: 0
      t.decimal :initial_amount,    precision: 10, scale: 2, null: false
      t.decimal :remaining_balance, precision: 10, scale: 2, null: false
      t.references :customer,      foreign_key: true, null: true
      t.references :sold_on_order, foreign_key: { to_table: :orders }, null: true
      t.references :issued_by,     foreign_key: { to_table: :users }, null: true
      t.datetime :activated_at
      t.datetime :voided_at
      t.timestamps
    end

    add_index :gift_certificates, :code, unique: true
    add_index :gift_certificates, :status
  end
end
