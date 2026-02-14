class CreateTaxCodes < ActiveRecord::Migration[8.1]
  def change
    create_table :tax_codes do |t|
      t.string :code, null: false, index: { unique: true }
      t.string :name, null: false
      t.decimal :rate, precision: 5, scale: 4, default: 0
      t.string :exemption_type
      t.string :province_code
      t.text :notes
      t.datetime :discarded_at, index: true
      t.timestamps
    end
  end
end
