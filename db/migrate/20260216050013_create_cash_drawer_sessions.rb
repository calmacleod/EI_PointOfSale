# frozen_string_literal: true

class CreateCashDrawerSessions < ActiveRecord::Migration[8.1]
  def change
    create_table :cash_drawer_sessions do |t|
      t.references :opened_by, null: false, foreign_key: { to_table: :users }
      t.references :closed_by, foreign_key: { to_table: :users }
      t.datetime :opened_at, null: false
      t.datetime :closed_at
      t.jsonb :opening_counts, null: false, default: {}
      t.jsonb :closing_counts
      t.integer :opening_total_cents, null: false
      t.integer :closing_total_cents
      t.text :notes

      t.timestamps
    end

    add_index :cash_drawer_sessions, :opened_at
    add_index :cash_drawer_sessions, :closed_at
  end
end
