class CreateCategorizations < ActiveRecord::Migration[8.1]
  def change
    create_table :categorizations do |t|
      t.references :categorizable, polymorphic: true, null: false
      t.references :category, null: false, foreign_key: true
      t.datetime :discarded_at, index: true
      t.timestamps
    end

    add_index :categorizations,
      [ :categorizable_type, :categorizable_id, :category_id ],
      unique: true,
      name: "index_categorizations_on_categorizable_and_category"
  end
end
