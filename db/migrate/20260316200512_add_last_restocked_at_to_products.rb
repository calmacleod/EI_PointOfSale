class AddLastRestockedAtToProducts < ActiveRecord::Migration[8.1]
  def change
    add_column :products, :last_restocked_at, :datetime
  end
end
