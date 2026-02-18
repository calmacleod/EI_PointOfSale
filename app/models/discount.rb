# frozen_string_literal: true

class Discount < ApplicationRecord
  include Discard::Model

  has_many :discount_items, dependent: :destroy
  has_many :order_discounts, dependent: :nullify
  has_many :customers, dependent: :nullify

  enum :discount_type, { percentage: 0, fixed_total: 1, fixed_per_item: 2 }

  validates :name, presence: true
  validates :discount_type, presence: true
  validates :value, presence: true, numericality: { greater_than: 0 }

  scope :currently_active, -> {
    kept
      .where(active: true)
      .where("starts_at IS NULL OR starts_at <= ?", Time.current)
      .where("ends_at IS NULL OR ends_at >= ?", Time.current)
  }

  def display_value
    helpers = ActionController::Base.helpers
    case discount_type
    when "percentage"    then "#{value.to_i}%"
    when "fixed_total"   then helpers.number_to_currency(value)
    when "fixed_per_item" then "#{helpers.number_to_currency(value)}/item"
    end
  end

  def display_type
    discount_type.humanize.downcase
  end
end
