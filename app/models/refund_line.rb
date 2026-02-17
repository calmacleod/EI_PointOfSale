# frozen_string_literal: true

class RefundLine < ApplicationRecord
  belongs_to :refund
  belongs_to :order_line

  validates :quantity, presence: true, numericality: { greater_than: 0, only_integer: true }
  validates :amount, presence: true, numericality: { greater_than: 0 }
end
