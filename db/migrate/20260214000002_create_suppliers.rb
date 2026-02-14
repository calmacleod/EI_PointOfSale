class CreateSuppliers < ActiveRecord::Migration[8.1]
  def change
    create_table :suppliers do |t|
      t.string :name, null: false
      t.string :phone
      t.datetime :discarded_at, index: true
      t.timestamps
    end
  end
end
