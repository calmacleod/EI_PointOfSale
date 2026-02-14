class Supplier < ApplicationRecord
  audited

  include Discard::Model
  include PgSearch::Model

  multisearchable against: [ :name, :phone ], if: :kept?
  pg_search_scope :search, against: [ :name, :phone ], using: { tsearch: { prefix: true } }

  validates :name, presence: true
end
