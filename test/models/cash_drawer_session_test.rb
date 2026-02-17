# frozen_string_literal: true

require "test_helper"

class CashDrawerSessionTest < ActiveSupport::TestCase
  setup do
    @user = users(:admin)
  end

  # ── Validations ────────────────────────────────────────────────────

  test "requires opened_by" do
    session = CashDrawerSession.new(opened_at: Time.current, opening_counts: { "$20" => 1 }, opening_total_cents: 2000)
    assert_not session.valid?
    assert_includes session.errors[:opened_by], "must exist"
  end

  test "requires opened_at" do
    session = CashDrawerSession.new(opened_by: @user, opening_counts: { "$20" => 1 }, opening_total_cents: 2000)
    assert_not session.valid?
    assert_includes session.errors[:opened_at], "can't be blank"
  end

  test "requires opening_counts" do
    session = CashDrawerSession.new(opened_by: @user, opened_at: Time.current, opening_total_cents: 0)
    assert_not session.valid?
    assert_includes session.errors[:opening_counts], "can't be blank"
  end

  test "requires opening_total_cents" do
    session = CashDrawerSession.new(opened_by: @user, opened_at: Time.current, opening_counts: { "$20" => 1 })
    assert_not session.valid?
  end

  test "opening_total_cents must be non-negative" do
    session = CashDrawerSession.new(opened_by: @user, opened_at: Time.current, opening_counts: { "$20" => 1 },
                                    opening_total_cents: -100)
    assert_not session.valid?
  end

  test "closing requires closed_by" do
    session = CashDrawerSession.new(
      opened_by: @user, opened_at: Time.current,
      opening_counts: { "$20" => 1 }, opening_total_cents: 2000,
      closed_at: Time.current, closing_counts: { "$20" => 1 }, closing_total_cents: 2000
    )
    assert_not session.valid?
    assert_includes session.errors[:closed_by], "must be present when closing the register"
  end

  test "valid open session" do
    session = CashDrawerSession.new(
      opened_by: @user, opened_at: Time.current,
      opening_counts: { "$20" => 5 }, opening_total_cents: 10_000
    )
    assert session.valid?
  end

  # ── Scopes ─────────────────────────────────────────────────────────

  test "open scope returns sessions without closed_at" do
    results = CashDrawerSession.open
    assert results.all?(&:open?)
  end

  test "closed scope returns sessions with closed_at" do
    results = CashDrawerSession.closed
    assert results.all?(&:closed?)
  end

  test "recent scope returns sessions ordered by opened_at desc" do
    results = CashDrawerSession.recent
    assert_equal results.to_a, results.sort_by(&:opened_at).reverse
  end

  # ── Status helpers ─────────────────────────────────────────────────

  test "open? returns true when closed_at is nil" do
    session = cash_drawer_sessions(:open_session)
    assert session.open?
    assert_not session.closed?
  end

  test "closed? returns true when closed_at is present" do
    session = cash_drawer_sessions(:closed_session)
    assert session.closed?
    assert_not session.open?
  end

  # ── Money helpers ──────────────────────────────────────────────────

  test "opening_total returns dollars" do
    session = cash_drawer_sessions(:closed_session)
    assert_equal 140.00, session.opening_total
  end

  test "closing_total returns dollars" do
    session = cash_drawer_sessions(:closed_session)
    assert_equal 140.50, session.closing_total
  end

  test "closing_total returns nil when not closed" do
    session = cash_drawer_sessions(:open_session)
    assert_nil session.closing_total
  end

  # ── Cash received & expected total ────────────────────────────────

  test "cash_received_cents sums cash payments on session orders" do
    session = cash_drawer_sessions(:closed_session)
    # completed_order has a cash payment of $33.88
    assert_equal 3388, session.cash_received_cents
  end

  test "cash_received_cents returns 0 when no orders" do
    session = cash_drawer_sessions(:open_session)
    assert_equal 0, session.cash_received_cents
  end

  test "expected_closing_total_cents equals opening plus cash received" do
    session = cash_drawer_sessions(:closed_session)
    assert_equal 14000 + 3388, session.expected_closing_total_cents
  end

  test "expected_closing_total returns dollars" do
    session = cash_drawer_sessions(:closed_session)
    assert_equal 173.88, session.expected_closing_total
  end

  test "discrepancy_cents uses expected closing total" do
    session = cash_drawer_sessions(:closed_session)
    # closing 14050 - expected 17388 = -3338
    assert_equal(-3338, session.discrepancy_cents)
  end

  test "discrepancy returns the difference in dollars" do
    session = cash_drawer_sessions(:closed_session)
    assert_equal(-33.38, session.discrepancy)
  end

  test "discrepancy returns nil when not closed" do
    session = cash_drawer_sessions(:open_session)
    assert_nil session.discrepancy
  end

  # ── Class methods ──────────────────────────────────────────────────

  test "current returns the open session" do
    current = CashDrawerSession.current
    assert_not_nil current
    assert current.open?
  end

  test "register_open? returns true when an open session exists" do
    assert CashDrawerSession.register_open?
  end

  # ── calculate_total_cents ──────────────────────────────────────────

  test "calculate_total_cents with coins" do
    counts = { "5c" => 10, "10c" => 5, "25c" => 4 }
    # 10*5 + 5*10 + 4*25 = 50 + 50 + 100 = 200 cents
    assert_equal 200, CashDrawerSession.calculate_total_cents(counts)
  end

  test "calculate_total_cents with bills" do
    counts = { "$5" => 2, "$20" => 3 }
    # 2*500 + 3*2000 = 1000 + 6000 = 7000 cents
    assert_equal 7000, CashDrawerSession.calculate_total_cents(counts)
  end

  test "calculate_total_cents with coin rolls" do
    counts = { "5c_roll" => 1, "$2_roll" => 1 }
    # 1*200 + 1*5000 = 5200 cents
    assert_equal 5200, CashDrawerSession.calculate_total_cents(counts)
  end

  test "calculate_total_cents with mixed denominations" do
    counts = { "25c" => 4, "$10" => 2, "$1_roll" => 1 }
    # 4*25 + 2*1000 + 1*2500 = 100 + 2000 + 2500 = 4600 cents
    assert_equal 4600, CashDrawerSession.calculate_total_cents(counts)
  end

  test "calculate_total_cents with blank hash returns 0" do
    assert_equal 0, CashDrawerSession.calculate_total_cents({})
    assert_equal 0, CashDrawerSession.calculate_total_cents(nil)
  end

  test "calculate_total_cents ignores unknown denomination keys" do
    counts = { "$20" => 1, "unknown" => 5 }
    assert_equal 2000, CashDrawerSession.calculate_total_cents(counts)
  end

  # ── Denominations constants ────────────────────────────────────────

  test "DENOMINATIONS includes all coins, bills, and rolls" do
    assert_includes CashDrawerSession::DENOMINATION_KEYS, "5c"
    assert_includes CashDrawerSession::DENOMINATION_KEYS, "$100"
    assert_includes CashDrawerSession::DENOMINATION_KEYS, "$2_roll"
    assert_equal 15, CashDrawerSession::DENOMINATION_KEYS.length
  end
end
