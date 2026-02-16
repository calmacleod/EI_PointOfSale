class AddTrimLogoToReceiptTemplates < ActiveRecord::Migration[8.1]
  def change
    add_column :receipt_templates, :trim_logo, :boolean, default: false, null: false
  end
end
