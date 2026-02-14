class CreateStores < ActiveRecord::Migration[8.1]
  def change
    create_table :stores do |t|
      t.string :name
      t.string :phone
      t.text :address
      t.string :email

      t.timestamps
    end
  end
end
