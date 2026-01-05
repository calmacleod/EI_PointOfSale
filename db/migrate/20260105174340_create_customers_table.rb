class CreateCustomersTable < ActiveRecord::Migration[8.1]
  def change
    # TODO:
    # - Add a unique member number (9 digit number?)
    # - Add an enum for account status
    # - Add a polymorphic address association
    # - Add a polymorphic discount association
    # - Add a foreign key to user who added the customer
    # - Add a foreign key to tax code
    # - Add a category (e.g. comics/ink/manga/etc.)
    create_table :customers do |t|
      t.string :name
      t.string :phone
      t.string :email
      t.boolean :active, null: false, default: true
      t.text :notes
      t.datetime :joining_date
      t.timestamps
    end
  end
end
