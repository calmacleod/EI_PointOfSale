# frozen_string_literal: true

class DiscountItem < ApplicationRecord
  belongs_to :discount
  belongs_to :discountable, polymorphic: true

  enum :exclusion_type, { allowed: 0, denied: 1 }

  validates :discountable_id,
            uniqueness: { scope: [ :discount_id, :discountable_type, :exclusion_type ] }

  scope :allowed, -> { where(exclusion_type: :allowed) }
  scope :denied, -> { where(exclusion_type: :denied) }

  def self.discountable_types
    %w[Product Service ProductGroup]
  end
end
