class Category < ApplicationRecord
  audited

  include Discard::Model
  include PgSearch::Model
  include AsyncPgSearch

  multisearchable against: [ :name ], if: :kept?
  pg_search_scope :search, against: [ :name ], using: { tsearch: { prefix: true }, trigram: {} }

  has_many :categorizations, dependent: :destroy

  validates :name, presence: true
end
