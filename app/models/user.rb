class User < ApplicationRecord
  include PgSearch::Model

  multisearchable against: [ :name, :email_address, :notes ]
  pg_search_scope :search, against: [ :name, :email_address, :notes ], using: { tsearch: { prefix: true } }

  has_secure_password
  has_many :sessions, dependent: :destroy

  normalizes :email_address, with: ->(e) { e.strip.downcase }

  validates :theme, inclusion: { in: %w[light dark dim] }, allow_nil: false
  validates :font_size, inclusion: { in: %w[default large xlarge] }, allow_nil: false
end
