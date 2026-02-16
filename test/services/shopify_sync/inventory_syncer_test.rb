# frozen_string_literal: true

require "test_helper"

module ShopifySync
  class InventorySyncerTest < ActiveSupport::TestCase
    test "syncer is instantiable" do
      syncer = ShopifySync::InventorySyncer.new
      assert_respond_to syncer, :call
    end

    test "raises when shopify credentials not configured" do
      product = products(:dragon_shield_red)
      product.update!(sync_to_shopify: true, shopify_inventory_item_id: "gid://shopify/InventoryItem/123")

      assert_raises(RuntimeError, /Shopify credentials not configured/) do
        ShopifySync::InventorySyncer.new.call(product)
      end
    end
  end
end
