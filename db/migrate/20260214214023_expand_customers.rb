# frozen_string_literal: true

class ExpandCustomers < ActiveRecord::Migration[8.1]
  def change
    add_column :customers, :member_number, :string
    add_column :customers, :address_line1, :string
    add_column :customers, :address_line2, :string
    add_column :customers, :city, :string
    add_column :customers, :province, :string
    add_column :customers, :postal_code, :string
    add_column :customers, :country, :string
    add_column :customers, :account_status, :integer
    add_column :customers, :date_of_birth, :date
    add_column :customers, :alert, :text
    add_reference :customers, :added_by, foreign_key: { to_table: :users }

    add_index :customers, :member_number, unique: true
  end
end
