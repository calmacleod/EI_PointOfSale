class TaxCode < ApplicationRecord
  audited

  include Discard::Model
  include PgSearch::Model
  include AsyncPgSearch

  multisearchable against: [ :code, :name, :notes ], if: :kept?
  pg_search_scope :search, against: [ :code, :name, :notes ], using: { tsearch: { prefix: true }, trigram: {} }
end
