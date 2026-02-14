class Store < ApplicationRecord
  audited

  normalizes :email, with: ->(e) { e.to_s.strip.downcase.presence }

  validates :name, presence: true

  # Formatted full address for display (e.g. receipts, headers).
  def address
    [ address_line1, address_line2, city, province, postal_code, country ].compact_blank.join(", ")
  end

  class << self
    def current
      first || create!(name: "Store")
    end
  end
end
