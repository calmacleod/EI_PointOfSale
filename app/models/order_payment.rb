# frozen_string_literal: true

class OrderPayment < ApplicationRecord
  belongs_to :order
  belongs_to :received_by, class_name: "User", optional: true
  belongs_to :gift_certificate, optional: true

  enum :payment_method, {
    cash: 0,
    debit: 1,
    credit: 2,
    store_credit: 3,
    gift_certificate: 4,
    other: 5
  }

  validates :payment_method, presence: true
  validates :amount, presence: true, numericality: { greater_than: 0 }
  validates :gift_certificate, presence: true, if: :gift_certificate?
  validate  :gift_certificate_is_redeemable,         if: :gift_certificate?
  validate  :gift_certificate_has_sufficient_balance, if: :gift_certificate?
  validate  :cash_tendered_sufficient, if: :cash?

  before_validation :round_cash_amount, if: :cash?
  before_validation :calculate_change, if: :cash?

  after_create  :decrement_gift_certificate_balance, if: :gift_certificate?
  after_destroy :restore_gift_certificate_balance,   if: :gift_certificate?

  def display_method
    payment_method.humanize
  end

  private

    def gift_certificate_is_redeemable
      return unless gift_certificate

      errors.add(:gift_certificate, "is not active or has no remaining balance") unless gift_certificate.redeemable?
    end

    def gift_certificate_has_sufficient_balance
      return unless gift_certificate && amount.present?

      if amount > gift_certificate.remaining_balance
        errors.add(:amount, "exceeds gift certificate balance of #{gift_certificate.remaining_balance}")
      end
    end

    def decrement_gift_certificate_balance
      gift_certificate.decrement_balance!(amount)
    end

    def restore_gift_certificate_balance
      gift_certificate.increment_balance!(amount)
    end

    def round_cash_amount
      self.amount          = (amount * 20).round / 20.0          if amount.present?
      self.amount_tendered = (amount_tendered * 20).round / 20.0 if amount_tendered.present?
    end

    def calculate_change
      return unless amount_tendered.present? && amount_tendered > 0

      self.change_given = [ amount_tendered - amount, 0 ].max
    end

    def cash_tendered_sufficient
      return unless amount.present? && amount_tendered.present?

      if amount_tendered < amount
        errors.add(:amount_tendered, "must be at least the payment amount ($#{amount})")
      end
    end
end
