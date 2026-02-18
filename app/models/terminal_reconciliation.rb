# frozen_string_literal: true

class TerminalReconciliation < ApplicationRecord
  audited async: true

  belongs_to :cash_drawer_session
  belongs_to :reconciled_by, class_name: "User", optional: true

  validates :cash_drawer_session_id, uniqueness: true
  validates :debit_total, numericality: { greater_than_or_equal_to: 0 }
  validates :credit_total, numericality: { greater_than_or_equal_to: 0 }

  def debit_discrepancy
    debit_total - (expected_debit_total || 0)
  end

  def credit_discrepancy
    credit_total - (expected_credit_total || 0)
  end

  def total_discrepancy
    debit_discrepancy + credit_discrepancy
  end

  def balanced?
    total_discrepancy == 0
  end
end
