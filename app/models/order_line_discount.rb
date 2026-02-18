# frozen_string_literal: true

class OrderLineDiscount < ApplicationRecord
  belongs_to :order_line
  belongs_to :source_discount, class_name: "Discount", optional: true

  enum :discount_type, { percentage: 0, fixed_amount: 1, fixed_per_item: 2 }

  validates :name, presence: true
  validates :discount_type, presence: true
  validates :value, presence: true, numericality: { greater_than_or_equal_to: 0 }
  validates :calculated_amount, presence: true, numericality: { greater_than_or_equal_to: 0 }
  validates :excluded_quantity, presence: true, numericality: { greater_than_or_equal_to: 0 }

  scope :active, -> { joins(:order_line).where("order_line_discounts.excluded_quantity < order_lines.quantity") }
  scope :fully_excluded, -> { joins(:order_line).where("order_line_discounts.excluded_quantity >= order_lines.quantity") }
  scope :auto_applied, -> { where(auto_applied: true) }
  scope :manual, -> { where(auto_applied: false) }

  # Returns the quantity that receives this discount
  def applied_quantity
    [ order_line.quantity - excluded_quantity, 0 ].max
  end

  # Returns true if no units receive the discount
  def fully_excluded?
    excluded_quantity >= order_line.quantity
  end

  # Returns true if at least one unit receives the discount
  def active?
    applied_quantity > 0
  end

  # Returns the number of units that have the discount
  def discounted_units_count
    applied_quantity
  end

  # Increment excluded quantity by 1 (remove discount from one more unit)
  def exclude_one!
    return if fully_excluded?

    update!(excluded_quantity: excluded_quantity + 1)
  end

  # Decrement excluded quantity by 1 (add discount back to one unit)
  def restore_one!
    return if excluded_quantity <= 0

    update!(excluded_quantity: excluded_quantity - 1)
  end

  # Fully exclude the discount (remove from all units)
  def exclude_all!
    update!(excluded_quantity: order_line.quantity)
  end

  # Fully restore the discount (apply to all units)
  def restore_all!
    update!(excluded_quantity: 0)
  end

  def display_value
    case discount_type
    when "percentage"
      "#{value.to_i}%"
    when "fixed_amount"
      ActionController::Base.helpers.number_to_currency(value)
    when "fixed_per_item"
      "#{ActionController::Base.helpers.number_to_currency(value)}/item"
    end
  end

  def description
    "#{name} (#{display_value})"
  end
end
