# frozen_string_literal: true

class CreateReceiptTemplates < ActiveRecord::Migration[8.1]
  def change
    create_table :receipt_templates do |t|
      t.string :name, null: false
      t.integer :paper_width_mm, null: false, default: 80
      t.integer :chars_per_line, null: false, default: 48
      t.boolean :show_store_name, default: true, null: false
      t.boolean :show_store_address, default: true, null: false
      t.boolean :show_store_phone, default: true, null: false
      t.boolean :show_store_email, default: false, null: false
      t.text :header_text
      t.text :footer_text
      t.boolean :show_date_time, default: true, null: false
      t.boolean :show_cashier_name, default: true, null: false
      t.boolean :active, default: false, null: false

      t.timestamps
    end
  end
end
