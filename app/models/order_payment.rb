# frozen_string_literal: true

class OrderPayment < ApplicationRecord
  belongs_to :order
  belongs_to :received_by, class_name: "User", optional: true

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

  before_validation :calculate_change, if: :cash?

  def display_method
    payment_method.humanize
  end

  private

    def calculate_change
      return unless amount_tendered.present? && amount_tendered > 0

      self.change_given = [ amount_tendered - amount, 0 ].max
    end
end
