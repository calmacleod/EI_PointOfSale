# frozen_string_literal: true

require "test_helper"

class CashDrawerControllerTest < ActionDispatch::IntegrationTest
  setup do
    sign_in_as(users(:admin))
    # Close any fixture-open sessions so tests start clean
    CashDrawerSession.open.update_all(closed_at: Time.current, closed_by_id: users(:admin).id,
                                      closing_counts: {}, closing_total_cents: 0)
  end

  # ── Show ───────────────────────────────────────────────────────────

  test "show renders when register is closed" do
    get cash_drawer_path
    assert_response :success
    assert_includes response.body, "Open Register"
  end

  test "show renders when register is open" do
    open_register!
    get cash_drawer_path
    assert_response :success
    assert_includes response.body, "Close Register"
  end

  # ── Open ───────────────────────────────────────────────────────────

  test "new_open renders the denomination form" do
    get open_cash_drawer_path
    assert_response :success
    assert_includes response.body, "Open Register"
  end

  test "new_open redirects when register is already open" do
    open_register!
    get open_cash_drawer_path
    assert_redirected_to cash_drawer_path
  end

  test "create_open opens the register" do
    assert_difference "CashDrawerSession.count", 1 do
      post open_cash_drawer_path, params: {
        counts: { "$20" => "5", "$10" => "3", "25c" => "20" }
      }
    end

    assert_redirected_to cash_drawer_path
    session = CashDrawerSession.current
    assert session.open?
    assert_equal users(:admin).id, session.opened_by_id
    # 5*2000 + 3*1000 + 20*25 = 10000 + 3000 + 500 = 13500
    assert_equal 13_500, session.opening_total_cents
  end

  test "create_open rejects when register is already open" do
    open_register!
    assert_no_difference "CashDrawerSession.count" do
      post open_cash_drawer_path, params: { counts: { "$20" => "1" } }
    end
    assert_redirected_to cash_drawer_path
  end

  # ── Close ──────────────────────────────────────────────────────────

  test "new_close renders the closing form" do
    open_register!
    get close_cash_drawer_path
    assert_response :success
    assert_includes response.body, "Close Register"
  end

  test "new_close redirects when register is not open" do
    get close_cash_drawer_path
    assert_redirected_to cash_drawer_path
  end

  test "create_close closes the register and redirects to reconcile" do
    open_register!
    session = CashDrawerSession.current

    post close_cash_drawer_path, params: {
      counts: { "$20" => "5", "$10" => "4" }
    }

    assert_redirected_to reconcile_cash_drawer_path
    session.reload
    assert session.closed?
    assert_equal users(:admin).id, session.closed_by_id
    # 5*2000 + 4*1000 = 14000
    assert_equal 14_000, session.closing_total_cents
  end

  test "create_close redirects when register is not open" do
    post close_cash_drawer_path, params: { counts: { "$20" => "1" } }
    assert_redirected_to cash_drawer_path
  end

  # ── History ────────────────────────────────────────────────────────

  test "history renders past sessions" do
    get history_cash_drawer_path
    assert_response :success
  end

  # ── Session detail ─────────────────────────────────────────────────

  test "session_detail renders a specific session" do
    session = cash_drawer_sessions(:closed_session)
    get session_detail_cash_drawer_path(session)
    assert_response :success
  end

  # ── Reconcile ──────────────────────────────────────────────────────
  # Note: setup closes all open sessions (including the open_session fixture),
  # leaving it as the pending reconciliation session for these tests.

  test "new_reconcile renders when a closed unreconciled session exists" do
    # open_session fixture gets closed in setup → it becomes the pending session
    get reconcile_cash_drawer_path
    assert_response :success
    assert_includes response.body, "Reconcile Terminal"
  end

  test "new_reconcile redirects when no session pending reconciliation" do
    reconcile_all_pending_sessions!
    get reconcile_cash_drawer_path
    assert_redirected_to cash_drawer_path
  end

  test "create_reconcile saves and redirects to session detail" do
    pending = CashDrawerSession.pending_reconciliation
    assert_not_nil pending

    assert_difference "TerminalReconciliation.count", 1 do
      post reconcile_cash_drawer_path, params: {
        debit_total: "50.00",
        credit_total: "75.00",
        notes: "Balanced"
      }
    end

    assert_redirected_to session_detail_cash_drawer_path(pending)
    rec = pending.reload.terminal_reconciliation
    assert_in_delta 50.00, rec.debit_total, 0.001
    assert_in_delta 75.00, rec.credit_total, 0.001
    assert_equal "Balanced", rec.notes
    assert_equal users(:admin).id, rec.reconciled_by_id
  end

  test "create_reconcile redirects when no session pending reconciliation" do
    reconcile_all_pending_sessions!
    assert_no_difference "TerminalReconciliation.count" do
      post reconcile_cash_drawer_path, params: { debit_total: "0", credit_total: "0" }
    end
    assert_redirected_to cash_drawer_path
  end

  # ── Common user access ─────────────────────────────────────────────

  test "common user can access cash drawer" do
    sign_in_as(users(:one))
    get cash_drawer_path
    assert_response :success
  end

  test "common user can open register" do
    sign_in_as(users(:one))
    assert_difference "CashDrawerSession.count", 1 do
      post open_cash_drawer_path, params: { counts: { "$20" => "1" } }
    end
    assert_redirected_to cash_drawer_path
  end

  # ── Unauthenticated access ─────────────────────────────────────────

  test "unauthenticated user is redirected" do
    sign_out
    get cash_drawer_path
    assert_redirected_to new_session_path
  end

  private

    def open_register!
      CashDrawerSession.create!(
        opened_by: users(:admin),
        opened_at: Time.current,
        opening_counts: { "$20" => 5 },
        opening_total_cents: 10_000
      )
    end

    def close_register!
      CashDrawerSession.create!(
        opened_by: users(:admin),
        closed_by: users(:admin),
        opened_at: 2.hours.ago,
        closed_at: 1.hour.ago,
        opening_counts: { "$20" => 5 },
        opening_total_cents: 10_000,
        closing_counts: { "$20" => 5 },
        closing_total_cents: 10_000
      )
    end

    def reconcile_all_pending_sessions!
      while (pending = CashDrawerSession.pending_reconciliation)
        TerminalReconciliation.create!(
          cash_drawer_session: pending,
          debit_total: 0, credit_total: 0,
          expected_debit_total: 0, expected_credit_total: 0
        )
      end
    end
end
