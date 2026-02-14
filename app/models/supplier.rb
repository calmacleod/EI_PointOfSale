class Supplier < ApplicationRecord
  include Discard::Model

  validates :name, presence: true
end
