# frozen_string_literal: true

class OrderDiscountItem < ApplicationRecord
  belongs_to :order_discount
  belongs_to :order_line
end
