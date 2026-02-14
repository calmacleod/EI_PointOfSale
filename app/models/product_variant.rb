class ProductVariant < ApplicationRecord
  include Discard::Model

  belongs_to :product
  belongs_to :supplier, optional: true

  validates :code, presence: true, uniqueness: true
end
