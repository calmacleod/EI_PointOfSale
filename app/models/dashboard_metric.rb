# frozen_string_literal: true

class DashboardMetric < ApplicationRecord
  validates :key, presence: true, uniqueness: true
  validates :computed_at, presence: true
end
