# frozen_string_literal: true

class RefreshProductCountJob < ApplicationJob
  queue_as :low

  def perform
    Product.refresh_kept_count!
  end
end
