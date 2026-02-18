# frozen_string_literal: true

class Customer < ApplicationRecord
  audited async: true

  include Discard::Model
  include PgSearch::Model
  include AsyncPgSearch

  multisearchable against: [ :name, :member_number, :email ], if: :kept?
  pg_search_scope :search, against: [ :name, :member_number, :email, :phone ], using: { tsearch: { prefix: true }, trigram: {} }

  belongs_to :added_by, class_name: "User", optional: true
  belongs_to :tax_code, optional: true

  has_many :orders, dependent: :nullify

  validates :name, presence: true
  validates :member_number, uniqueness: true, allow_nil: true

  def address
    [ address_line1, address_line2, city, province, postal_code, country ].compact_blank.join(", ")
  end
end
