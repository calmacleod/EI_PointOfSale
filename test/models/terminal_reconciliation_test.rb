# frozen_string_literal: true

require "test_helper"

class TerminalReconciliationTest < ActiveSupport::TestCase
  setup do
    @reconciliation = terminal_reconciliations(:reconciled_session)
  end

  # ── Validations ────────────────────────────────────────────────────

  test "requires cash_drawer_session" do
    rec = TerminalReconciliation.new(debit_total: 0, credit_total: 0)
    assert_not rec.valid?
    assert_includes rec.errors[:cash_drawer_session], "must exist"
  end

  test "debit_total must be non-negative" do
    @reconciliation.debit_total = -1
    assert_not @reconciliation.valid?
    assert_includes @reconciliation.errors[:debit_total], "must be greater than or equal to 0"
  end

  test "credit_total must be non-negative" do
    @reconciliation.credit_total = -1
    assert_not @reconciliation.valid?
    assert_includes @reconciliation.errors[:credit_total], "must be greater than or equal to 0"
  end

  test "cash_drawer_session_id must be unique" do
    duplicate = TerminalReconciliation.new(
      cash_drawer_session: @reconciliation.cash_drawer_session,
      debit_total: 10, credit_total: 20
    )
    assert_not duplicate.valid?
    assert_includes duplicate.errors[:cash_drawer_session_id], "has already been taken"
  end

  # ── Discrepancy methods ─────────────────────────────────────────────

  test "debit_discrepancy returns actual minus expected" do
    # debit_total: 55.00, expected_debit_total: 55.00
    assert_equal 0, @reconciliation.debit_discrepancy
  end

  test "credit_discrepancy returns actual minus expected" do
    # credit_total: 30.00, expected_credit_total: 28.50
    assert_in_delta 1.50, @reconciliation.credit_discrepancy, 0.001
  end

  test "total_discrepancy sums debit and credit discrepancies" do
    assert_in_delta 1.50, @reconciliation.total_discrepancy, 0.001
  end

  test "balanced? returns true when total discrepancy is zero" do
    @reconciliation.debit_total = @reconciliation.expected_debit_total
    @reconciliation.credit_total = @reconciliation.expected_credit_total
    assert @reconciliation.balanced?
  end

  test "balanced? returns false when there is a discrepancy" do
    assert_not @reconciliation.balanced?
  end

  test "debit_discrepancy handles nil expected_debit_total" do
    @reconciliation.expected_debit_total = nil
    @reconciliation.debit_total = 30.00
    assert_in_delta 30.00, @reconciliation.debit_discrepancy, 0.001
  end

  test "credit_discrepancy handles nil expected_credit_total" do
    @reconciliation.expected_credit_total = nil
    @reconciliation.credit_total = 50.00
    assert_in_delta 50.00, @reconciliation.credit_discrepancy, 0.001
  end
end
