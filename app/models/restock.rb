class Restock < ApplicationRecord
  belongs_to :product
  belongs_to :user

  validates :quantity, presence: true, numericality: { greater_than: 0 }
  validates :stock_level_after, presence: true
end
