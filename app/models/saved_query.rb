# frozen_string_literal: true

class SavedQuery < ApplicationRecord
  belongs_to :user

  validates :name, presence: true
  validates :resource_type, presence: true

  scope :for_resource, ->(type) { where(resource_type: type).order(:name) }
end
