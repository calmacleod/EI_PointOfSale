class CreateUsersTable < ActiveRecord::Migration[8.1]
  def change
    create_table :users do |t|
      t.string :name

      t.string :phone

      t.string :email_address, null: false
      t.string :password_digest, null: false

      t.boolean :active, null: false, default: true

      t.text :notes

      t.string :type, null: false, default: "User"

      t.timestamps
    end

    add_index :users, :email_address, unique: true
  end
end
