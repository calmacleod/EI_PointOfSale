class ReplaceAddressWithStructuredFieldsOnStores < ActiveRecord::Migration[8.1]
  def up
    add_column :stores, :address_line1, :string
    add_column :stores, :address_line2, :string
    add_column :stores, :city, :string
    add_column :stores, :province, :string
    add_column :stores, :postal_code, :string
    add_column :stores, :country, :string

    reversible do |dir|
      dir.up do
        execute <<-SQL.squish
          UPDATE stores SET address_line1 = address WHERE address IS NOT NULL AND address != ''
        SQL
      end
    end

    remove_column :stores, :address, :text
  end

  def down
    add_column :stores, :address, :text

    execute <<-SQL.squish
      UPDATE stores SET address = trim(
        concat_ws(', ',
          nullif(trim(address_line1), ''),
          nullif(trim(address_line2), ''),
          nullif(trim(city), ''),
          nullif(trim(province), ''),
          nullif(trim(postal_code), ''),
          nullif(trim(country), '')
        )
      )
    SQL

    remove_column :stores, :address_line1, :string
    remove_column :stores, :address_line2, :string
    remove_column :stores, :city, :string
    remove_column :stores, :province, :string
    remove_column :stores, :postal_code, :string
    remove_column :stores, :country, :string
  end
end
