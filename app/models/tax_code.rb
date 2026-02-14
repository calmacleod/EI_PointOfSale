class TaxCode < ApplicationRecord
  include Discard::Model
  include PgSearch::Model

  multisearchable against: [ :code, :name, :notes ], if: :kept?
  pg_search_scope :search, against: [ :code, :name, :notes ], using: { tsearch: { prefix: true } }
end
