class ProductVariant < ApplicationRecord
  audited

  include Discard::Model
  include PgSearch::Model

  multisearchable against: [ :name, :code, :notes ], if: :kept?
  pg_search_scope :search, against: [ :name, :code, :notes ], using: { tsearch: { prefix: true }, trigram: {} }

  belongs_to :product
  belongs_to :supplier, optional: true

  validates :code, presence: true, uniqueness: true

  # Instant exact-match lookup for barcode scans.
  # Uses the unique index on `code` — no full-text overhead.
  def self.find_by_exact_code(code)
    kept.find_by(code: code.to_s.strip)
  end
end
