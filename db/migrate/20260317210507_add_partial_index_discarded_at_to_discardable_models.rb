class AddPartialIndexDiscardedAtToDiscardableModels < ActiveRecord::Migration[8.1]
  def change
    tables = %i[categories categorizations customers discounts orders products services suppliers tax_codes]

    tables.each do |table|
      add_index table, :discarded_at,
                where: "discarded_at IS NULL",
                name: "index_#{table}_on_discarded_at_null"
    end
  end
end
