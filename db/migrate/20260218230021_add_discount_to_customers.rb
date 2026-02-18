class AddDiscountToCustomers < ActiveRecord::Migration[8.1]
  def change
    add_reference :customers, :discount, null: true, foreign_key: true
  end
end
