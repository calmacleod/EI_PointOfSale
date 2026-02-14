class Service < ApplicationRecord
  include Discard::Model
  include Categorizable

  belongs_to :tax_code, optional: true
  belongs_to :added_by, class_name: "User", optional: true

  validates :name, presence: true
  validates :price, presence: true, numericality: { greater_than_or_equal_to: 0 }
end
