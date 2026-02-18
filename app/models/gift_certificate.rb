# frozen_string_literal: true

class GiftCertificate < ApplicationRecord
  include Sellable
  include PgSearch::Model
  include AsyncPgSearch
  audited

  multisearchable against: [ :code ], if: :active?
  pg_search_scope :search, against: [ :code ],
    using: { tsearch: { prefix: true }, trigram: {} }

  belongs_to :customer, optional: true
  belongs_to :sold_on_order, class_name: "Order", optional: true
  belongs_to :issued_by, class_name: "User", optional: true

  has_many :redemptions, class_name: "OrderPayment", foreign_key: :gift_certificate_id, dependent: :nullify

  enum :status, { pending: 0, active: 1, voided: 2, exhausted: 3 }

  validates :initial_amount, numericality: { greater_than: 0 }
  validates :remaining_balance, numericality: { greater_than_or_equal_to: 0 }
  validates :code, presence: true, uniqueness: true

  before_validation :generate_code, on: :create
  before_validation :set_initial_balance, on: :create

  # Sellable interface
  def sellable_price      = initial_amount
  def sellable_tax_code   = nil
  def sellable_code       = code
  def sellable_name       = "Gift Certificate (#{code})"
  def sellable_tax_exempt? = true

  def self.find_redeemable(code)
    active.find_by(code: code.to_s.strip.upcase)
  end

  def redeemable?
    active? && remaining_balance > 0
  end

  def decrement_balance!(amount)
    with_lock do
      raise ArgumentError, "Insufficient balance" if amount > remaining_balance

      new_balance = (remaining_balance - amount).round(2)
      update!(remaining_balance: new_balance,
              status: new_balance.zero? ? :exhausted : :active)
    end
  end

  def increment_balance!(amount)
    with_lock do
      update!(remaining_balance: [ (remaining_balance + amount).round(2), initial_amount ].min,
              status: :active)
    end
  end

  private

    def generate_code
      return if code.present?

      loop do
        candidate = "GC-#{SecureRandom.alphanumeric(8).upcase}"
        self.code = candidate
        break unless self.class.exists?(code: candidate)
      end
    end

    def set_initial_balance
      self.remaining_balance = initial_amount if remaining_balance.blank? || remaining_balance.to_d.zero?
    end
end
