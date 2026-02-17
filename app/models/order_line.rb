# frozen_string_literal: true

class OrderLine < ApplicationRecord
  belongs_to :order, inverse_of: :order_lines
  belongs_to :sellable, polymorphic: true
  belongs_to :tax_code, optional: true

  has_many :refund_lines, dependent: :restrict_with_error

  validates :name, presence: true
  validates :quantity, presence: true, numericality: { greater_than: 0, only_integer: true }
  validates :unit_price, presence: true, numericality: { greater_than_or_equal_to: 0 }
  validates :line_total, presence: true

  before_validation :calculate_line_total

  # Snapshot product/service data at sale time.
  def snapshot_from_sellable!(sellable_record, customer_tax_code: nil)
    self.sellable = sellable_record
    self.code = sellable_record.sellable_code
    self.name = sellable_record.sellable_name
    self.unit_price = sellable_record.sellable_price

    effective_tax_code = customer_tax_code || sellable_record.sellable_tax_code
    if effective_tax_code
      self.tax_code = effective_tax_code
      self.tax_rate = effective_tax_code.rate || 0
    else
      self.tax_rate = 0
    end
  end

  def subtotal_before_discount
    (unit_price || 0) * (quantity || 0)
  end

  def taxable_amount
    subtotal_before_discount - (discount_amount || 0)
  end

  private

    def calculate_line_total
      self.tax_amount = (taxable_amount * (tax_rate || 0)).round(2)
      self.line_total = taxable_amount + tax_amount
    end
end
