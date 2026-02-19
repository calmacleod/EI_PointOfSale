class AddSectionOrderToReceiptTemplates < ActiveRecord::Migration[8.1]
  def change
    add_column :receipt_templates, :section_order, :jsonb, default: [], null: false
  end
end
