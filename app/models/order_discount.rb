# frozen_string_literal: true

class OrderDiscount < ApplicationRecord
  belongs_to :order
  belongs_to :applied_by, class_name: "User", optional: true
  belongs_to :discount, optional: true

  has_many :order_discount_items, dependent: :destroy
  has_many :order_lines, through: :order_discount_items

  enum :discount_type, { percentage: 0, fixed_amount: 1, fixed_per_item: 2 }
  enum :scope, { all_items: 0, specific_items: 1 }, prefix: :applies_to

  validates :name, presence: true
  validates :discount_type, presence: true
  validates :value, presence: true, numericality: { greater_than: 0 }

  def auto_applied?
    discount_id.present?
  end

  def display_value
    case discount_type
    when "percentage"    then "#{value.to_i}%"
    when "fixed_amount"  then ActionController::Base.helpers.number_to_currency(value)
    when "fixed_per_item" then "#{ActionController::Base.helpers.number_to_currency(value)}/item"
    end
  end
end
