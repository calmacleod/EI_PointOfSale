# frozen_string_literal: true

class DiscountItem < ApplicationRecord
  belongs_to :discount
  belongs_to :discountable, polymorphic: true

  validates :discountable_id, uniqueness: { scope: [ :discount_id, :discountable_type ] }
end
