class AddDisplayPreferencesToUsers < ActiveRecord::Migration[8.1]
  def change
    add_column :users, :theme, :string, default: "light", null: false
    add_column :users, :font_size, :string, default: "default", null: false
    add_column :users, :sidebar_collapsed, :boolean, default: false, null: false
  end
end
