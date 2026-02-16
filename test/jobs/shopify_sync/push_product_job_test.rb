# frozen_string_literal: true

require "test_helper"

module ShopifySync
  class PushProductJobTest < ActiveJob::TestCase
    test "enqueues job" do
      product = products(:dragon_shield_red)

      assert_enqueued_with(job: ShopifySync::PushProductJob) do
        ShopifySync::PushProductJob.perform_later(product.id)
      end
    end

    test "skips product when sync_to_shopify is false" do
      product = products(:dragon_shield_red)
      assert_not product.sync_to_shopify?

      assert_nothing_raised do
        ShopifySync::PushProductJob.perform_now(product.id)
      end
    end

    test "skips missing product" do
      assert_nothing_raised do
        ShopifySync::PushProductJob.perform_now(-1)
      end
    end
  end
end
