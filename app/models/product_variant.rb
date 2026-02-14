class ProductVariant < ApplicationRecord
  include Discard::Model
  include PgSearch::Model

  multisearchable against: [ :name, :code, :notes ], if: :kept?
  pg_search_scope :search, against: [ :name, :code, :notes ], using: { tsearch: { prefix: true } }

  belongs_to :product
  belongs_to :supplier, optional: true

  validates :code, presence: true, uniqueness: true
end
