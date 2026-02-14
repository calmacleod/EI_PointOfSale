class CreateCategories < ActiveRecord::Migration[8.1]
  def change
    create_table :categories do |t|
      t.string :name, null: false, index: { unique: true }
      t.datetime :discarded_at, index: true
      t.timestamps
    end
  end
end
