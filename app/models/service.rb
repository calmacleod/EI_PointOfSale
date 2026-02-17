class Service < ApplicationRecord
  audited

  include Discard::Model
  include Categorizable
  include Sellable
  include PgSearch::Model

  multisearchable against: [ :name, :code, :description ], if: :kept?
  pg_search_scope :search, against: [ :name, :code, :description ], using: { tsearch: { prefix: true }, trigram: {} }

  belongs_to :tax_code, optional: true
  belongs_to :added_by, class_name: "User", optional: true

  has_many :discount_items, as: :discountable, dependent: :destroy

  validates :name, presence: true
  validates :price, presence: true, numericality: { greater_than_or_equal_to: 0 }

  def sellable_price
    price
  end
end
