# frozen_string_literal: true

class AddDiscardedAtToCustomers < ActiveRecord::Migration[8.1]
  def change
    add_column :customers, :discarded_at, :datetime
    add_index :customers, :discarded_at
  end
end
