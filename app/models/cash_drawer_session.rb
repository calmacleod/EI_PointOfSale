# frozen_string_literal: true

class CashDrawerSession < ApplicationRecord
  audited async: true

  # ── Canadian denominations ─────────────────────────────────────────
  # Each key is the denomination label; the value is its dollar amount.
  COINS = {
    "5c"  => 0.05,
    "10c" => 0.10,
    "25c" => 0.25,
    "$1"  => 1.00,
    "$2"  => 2.00
  }.freeze

  BILLS = {
    "$5"   => 5.00,
    "$10"  => 10.00,
    "$20"  => 20.00,
    "$50"  => 50.00,
    "$100" => 100.00
  }.freeze

  COIN_ROLLS = {
    "5c_roll"  => { value: 2.00,  count: 40, coin: "5c",  label: "Nickel roll (40)" },
    "10c_roll" => { value: 5.00,  count: 50, coin: "10c", label: "Dime roll (50)" },
    "25c_roll" => { value: 10.00, count: 40, coin: "25c", label: "Quarter roll (40)" },
    "$1_roll"  => { value: 25.00, count: 25, coin: "$1",  label: "Loonie roll (25)" },
    "$2_roll"  => { value: 50.00, count: 25, coin: "$2",  label: "Toonie roll (25)" }
  }.freeze

  # Flat hash: denomination key => dollar value (coins + bills + rolls)
  DENOMINATIONS = COINS.merge(BILLS).merge(COIN_ROLLS.transform_values { |v| v[:value] }).freeze
  DENOMINATION_KEYS = DENOMINATIONS.keys.freeze

  # ── Associations ───────────────────────────────────────────────────
  belongs_to :opened_by, class_name: "User"
  belongs_to :closed_by, class_name: "User", optional: true
  has_many :orders
  has_one :terminal_reconciliation

  # ── Validations ────────────────────────────────────────────────────
  validates :opened_at, presence: true
  validates :opening_counts, presence: true
  validates :opening_total_cents, presence: true, numericality: { greater_than_or_equal_to: 0 }
  validates :closing_total_cents, numericality: { greater_than_or_equal_to: 0 }, allow_nil: true
  validate :closing_requires_closed_by, if: :closed_at?

  # ── Scopes ─────────────────────────────────────────────────────────
  scope :open,   -> { where(closed_at: nil) }
  scope :closed, -> { where.not(closed_at: nil) }
  scope :recent, -> { order(opened_at: :desc).limit(20) }

  # ── Status helpers ─────────────────────────────────────────────────

  def open?
    closed_at.nil?
  end

  def closed?
    closed_at.present?
  end

  def day_complete?
    closed? && terminal_reconciliation.present?
  end

  # ── Money helpers ──────────────────────────────────────────────────

  def opening_total
    (opening_total_cents || 0) / 100.0
  end

  def closing_total
    return nil if closing_total_cents.nil?

    closing_total_cents / 100.0
  end

  def cash_received_cents
    orders.joins(:order_payments)
          .where(order_payments: { payment_method: :cash })
          .sum("order_payments.amount * 100").round
  end

  def electronic_payments_total(method)
    orders.joins(:order_payments)
          .where(order_payments: { payment_method: method })
          .sum("order_payments.amount")
  end

  def expected_closing_total_cents
    (opening_total_cents || 0) + cash_received_cents
  end

  def expected_closing_total
    expected_closing_total_cents / 100.0
  end

  def discrepancy_cents
    return nil unless closed?

    (closing_total_cents || 0) - expected_closing_total_cents
  end

  def discrepancy
    return nil unless closed?

    (discrepancy_cents || 0) / 100.0
  end

  # ── Class methods ──────────────────────────────────────────────────

  def self.current
    open.order(opened_at: :desc).first
  end

  def self.register_open?
    open.exists?
  end

  def self.pending_reconciliation
    closed.left_joins(:terminal_reconciliation)
          .where(terminal_reconciliations: { id: nil })
          .order(closed_at: :desc)
          .first
  end

  # Calculate total cents from a denomination counts hash.
  # counts: { "5c" => 10, "$20" => 3, ... }
  def self.calculate_total_cents(counts)
    return 0 if counts.blank?

    counts.sum do |denom, qty|
      qty = qty.to_i
      value = DENOMINATIONS[denom]
      next 0 unless value

      (value * 100).round * qty
    end
  end

  private

    def closing_requires_closed_by
      errors.add(:closed_by, "must be present when closing the register") if closed_by.nil?
    end
end
