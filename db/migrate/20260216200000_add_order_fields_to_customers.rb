class AddOrderFieldsToCustomers < ActiveRecord::Migration[8.1]
  def change
    add_reference :customers, :tax_code, foreign_key: true, null: true
    add_column :customers, :status_card_number, :string
  end
end
