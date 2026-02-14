class Category < ApplicationRecord
  audited

  include Discard::Model
  include PgSearch::Model

  multisearchable against: [ :name ], if: :kept?
  pg_search_scope :search, against: [ :name ], using: { tsearch: { prefix: true } }

  has_many :categorizations, dependent: :destroy

  validates :name, presence: true
end
