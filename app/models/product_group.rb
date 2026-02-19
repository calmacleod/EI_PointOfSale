class ProductGroup < ApplicationRecord
  include PgSearch::Model

  pg_search_scope :search, against: [ :name ],
    using: { tsearch: { prefix: true }, trigram: {} }

  has_many :products, dependent: :nullify
  has_many :discount_items, as: :discountable, dependent: :destroy

  validates :name, presence: true
end
