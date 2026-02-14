# frozen_string_literal: true

class RefreshDashboardMetricsJob < ApplicationJob
  queue_as :low

  def perform
    DashboardMetrics.refresh!
  end
end
