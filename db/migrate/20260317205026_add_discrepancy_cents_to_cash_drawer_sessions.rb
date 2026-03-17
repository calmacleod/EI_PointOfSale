class AddDiscrepancyCentsToCashDrawerSessions < ActiveRecord::Migration[8.1]
  def change
    add_column :cash_drawer_sessions, :discrepancy_cents, :integer
  end
end
