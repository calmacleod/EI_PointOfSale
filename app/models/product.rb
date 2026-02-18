class Product < ApplicationRecord
  audited

  include Discard::Model
  include Categorizable
  include Sellable
  include PgSearch::Model
  include AsyncPgSearch

  multisearchable against: [ :name, :code, :notes ], if: :kept?
  pg_search_scope :search, against: [ :name, :code, :notes ],
    using: { tsearch: { prefix: true }, trigram: {} }

  belongs_to :tax_code, optional: true
  belongs_to :supplier, optional: true
  belongs_to :added_by, class_name: "User", optional: true
  belongs_to :product_group, optional: true

  has_many :discount_items, as: :discountable, dependent: :destroy

  has_many_attached :images

  validates :name, presence: true
  validates :code, presence: true, uniqueness: true

  # Barcode scan lookup — uses the unique index on `code`.
  def self.find_by_exact_code(code)
    kept.find_by(code: code.to_s.strip)
  end

  def sellable_price
    selling_price || 0
  end
end
