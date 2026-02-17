# frozen_string_literal: true

class OrderDiscount < ApplicationRecord
  belongs_to :order
  belongs_to :applied_by, class_name: "User", optional: true

  has_many :order_discount_items, dependent: :destroy
  has_many :order_lines, through: :order_discount_items

  enum :discount_type, { percentage: 0, fixed_amount: 1 }
  enum :scope, { all_items: 0, specific_items: 1 }, prefix: :applies_to

  validates :name, presence: true
  validates :discount_type, presence: true
  validates :value, presence: true, numericality: { greater_than: 0 }

  def display_value
    if percentage?
      "#{value}%"
    else
      ActionController::Base.helpers.number_to_currency(value)
    end
  end
end
