# frozen_string_literal: true

require "test_helper"

class RefreshProductCountJobTest < ActiveJob::TestCase
  test "perform refreshes the shared exact count cache" do
    cache = ActiveSupport::Cache::MemoryStore.new

    Rails.stub(:cache, cache) { RefreshProductCountJob.perform_now }

    assert_equal Product.kept.count, cache.read(Product::KEPT_COUNT_CACHE_KEY)
  end
end
