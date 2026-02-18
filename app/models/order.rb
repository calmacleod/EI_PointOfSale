# frozen_string_literal: true

class Order < ApplicationRecord
  audited

  include Discard::Model
  include PgSearch::Model
  include AsyncPgSearch

  multisearchable against: [ :number, :notes ], if: :kept?
  pg_search_scope :search, against: [ :number, :notes ],
    associated_against: { customer: [ :name ] },
    using: { tsearch: { prefix: true }, trigram: {} }

  # ── Enums ───────────────────────────────────────────────────────────
  enum :status, {
    draft: 0,
    held: 1,
    completed: 2,
    voided: 3,
    refunded: 4,
    partially_refunded: 5,
    cancelled: 6
  }

  # ── Associations ────────────────────────────────────────────────────
  belongs_to :customer, optional: true
  belongs_to :created_by, class_name: "User"
  belongs_to :cash_drawer_session, optional: true

  has_many :order_lines, -> { order(:position) }, dependent: :destroy, inverse_of: :order
  has_many :order_line_discounts, through: :order_lines
  has_many :order_payments, dependent: :destroy
  has_many :order_discounts, dependent: :destroy
  has_many :order_events, dependent: :destroy
  has_many :refunds, dependent: :restrict_with_error

  # ── Validations ─────────────────────────────────────────────────────
  validates :number, presence: true, uniqueness: true
  validates :status, presence: true

  # ── Callbacks ───────────────────────────────────────────────────────
  before_validation :generate_number, on: :create
  before_update :prevent_completed_mutation

  # ── Scopes ──────────────────────────────────────────────────────────
  scope :active, -> { where(status: [ :draft, :held ]) }
  scope :recent, -> { order(created_at: :desc) }

  # ── Money helpers ───────────────────────────────────────────────────

  def amount_paid
    order_payments.sum(:amount)
  end

  def amount_remaining
    remaining = total - amount_paid
    remaining < 0.03 ? 0 : remaining
  end

  def payment_complete?
    (total - amount_paid) < 0.03
  end

  def finalized?
    completed? || voided? || refunded? || partially_refunded? || cancelled?
  end

  # ── Display helpers ─────────────────────────────────────────────────

  def display_status
    status.humanize
  end

  def customer_name
    customer&.name || "Quick Sale"
  end

  private

    def generate_number
      return if number.present?

      last_number = Order.unscoped.maximum(:number)
      next_seq = if last_number.present?
        last_number.delete_prefix("ORD-").to_i + 1
      else
        1
      end

      self.number = "ORD-#{next_seq.to_s.rjust(6, '0')}"
    end

    def prevent_completed_mutation
      return unless status_in_database.present?
      return unless %w[completed voided refunded partially_refunded cancelled].include?(status_in_database)

      # Allow status changes for refund processing
      return if only_status_and_timestamps_changed?

      raise ActiveRecord::ReadOnlyRecord,
        "Completed orders cannot be modified (order #{number})"
    end

    def only_status_and_timestamps_changed?
      (changed - %w[status updated_at discarded_at]).empty?
    end
end
