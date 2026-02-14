class Category < ApplicationRecord
  include Discard::Model

  has_many :categorizations, dependent: :destroy

  validates :name, presence: true
end
