# frozen_string_literal: true

class Discount < ApplicationRecord
  include Discard::Model

  has_many :discount_items, dependent: :destroy
  has_many :allowed_items, -> { allowed }, class_name: "DiscountItem"
  has_many :denied_items, -> { denied }, class_name: "DiscountItem"
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

  def denies?(sellable)
    return false unless per_item_discount?

    sellable_type = sellable.class.name
    sellable_id = sellable.id

    denied_set = build_denied_set
    return true if denied_set.include?([ sellable_type, sellable_id ])

    if sellable.respond_to?(:product_group) && sellable.product_group.present?
      return true if denied_set.include?([ "ProductGroup", sellable.product_group_id ])
    end

    false
  end

  def allows?(sellable)
    return false if denies?(sellable)
    return true if applies_to_all?

    sellable_type = sellable.class.name
    sellable_id = sellable.id

    allowed_set = build_allowed_set
    return true if allowed_set.include?([ sellable_type, sellable_id ])

    if sellable.respond_to?(:product_group) && sellable.product_group.present?
      return true if allowed_set.include?([ "ProductGroup", sellable.product_group_id ])
    end

    false
  end

  def per_item_discount?
    fixed_per_item? || percentage?
  end

  private

    def build_denied_set
      @denied_set ||= denied_items.map do |item|
        [ item.discountable_type, item.discountable_id ]
      end.to_set
    end

    def build_allowed_set
      @allowed_set ||= allowed_items.map do |item|
        [ item.discountable_type, item.discountable_id ]
      end.to_set
    end
end
