# frozen_string_literal: true

# Shared interface for models that can appear on order lines (Product, Service).
module Sellable
  extend ActiveSupport::Concern

  included do
    has_many :order_lines, as: :sellable, dependent: :restrict_with_error
  end

  # The price to use when adding this item to an order.
  def sellable_price
    raise NotImplementedError, "#{self.class.name} must implement #sellable_price"
  end

  # The tax code associated with this sellable, or nil.
  def sellable_tax_code
    respond_to?(:tax_code) ? tax_code : nil
  end

  # A display code for the order line snapshot.
  def sellable_code
    respond_to?(:code) ? code : nil
  end

  # A display name for the order line snapshot.
  def sellable_name
    name
  end
end

