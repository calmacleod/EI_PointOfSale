# frozen_string_literal: true

class CreateTerminalReconciliations < ActiveRecord::Migration[8.1]
  def change
    create_table :terminal_reconciliations do |t|
      t.references :cash_drawer_session, null: false, foreign_key: true, index: { unique: true }
      t.decimal :debit_total, precision: 10, scale: 2, null: false, default: 0
      t.decimal :credit_total, precision: 10, scale: 2, null: false, default: 0
      t.decimal :expected_debit_total, precision: 10, scale: 2
      t.decimal :expected_credit_total, precision: 10, scale: 2
      t.text :notes
      t.references :reconciled_by, null: true, foreign_key: { to_table: :users }
      t.datetime :reconciled_at

      t.timestamps
    end
  end
end
