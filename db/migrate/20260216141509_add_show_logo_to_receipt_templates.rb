# frozen_string_literal: true

class AddShowLogoToReceiptTemplates < ActiveRecord::Migration[8.1]
  def change
    add_column :receipt_templates, :show_logo, :boolean, default: true, null: false
  end
end
