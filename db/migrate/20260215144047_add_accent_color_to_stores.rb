class AddAccentColorToStores < ActiveRecord::Migration[8.1]
  def change
    add_column :stores, :accent_color, :string, default: "teal", null: false
  end
end
