class Product < ApplicationRecord
  include Discard::Model
  include Categorizable
  include PgSearch::Model

  multisearchable against: [ :name ], if: :kept?
  pg_search_scope :search, against: [ :name ], using: { tsearch: { prefix: true } }

  belongs_to :tax_code, optional: true
  validates :name, presence: true
  belongs_to :supplier, optional: true
  belongs_to :added_by, class_name: "User", optional: true

  has_many :variants, class_name: "ProductVariant", dependent: :destroy
end
