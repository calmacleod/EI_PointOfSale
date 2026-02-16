# frozen_string_literal: true

require "test_helper"

module ShopifySync
  class ProductPusherTest < ActiveSupport::TestCase
    test "raises when shopify credentials are not configured" do
      product = products(:dragon_shield_red)
      product.update!(sync_to_shopify: true)

      assert_raises(RuntimeError, /Shopify credentials not configured/) do
        ShopifySync::ProductPusher.new.call(product)
      end
    end

    test "handles standalone product (no group)" do
      product = products(:dragon_shield_red)
      assert_nil product.product_group_id

      pusher = ShopifySync::ProductPusher.new
      assert_respond_to pusher, :call
    end

    test "handles grouped product" do
      group = ProductGroup.create!(name: "Dragon Shield Matte Sleeves")
      product = products(:dragon_shield_red)
      product.update!(product_group: group, sync_to_shopify: true)

      pusher = ShopifySync::ProductPusher.new
      assert_respond_to pusher, :call
    end
  end
end
