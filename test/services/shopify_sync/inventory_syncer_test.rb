# frozen_string_literal: true

require "test_helper"

module ShopifySync
  class InventorySyncerTest < ActiveSupport::TestCase
    test "raises when shopify credentials not configured" do
      product = products(:dragon_shield_red)
      product.update!(sync_to_shopify: true, shopify_inventory_item_id: "gid://shopify/InventoryItem/123")

      Rails.application.credentials.stub(:dig, ->(*) { nil }) do
        assert_raises(RuntimeError, /Shopify credentials not configured/) do
          ShopifySync::InventorySyncer.new.call(product)
        end
      end
    end

    test "syncs inventory for a product and updates shopify_synced_at" do
      product = products(:dragon_shield_red)
      product.update!(sync_to_shopify: true, shopify_inventory_item_id: "gid://shopify/InventoryItem/123", stock_level: 10)

      responses = [
        # locations query
        shopify_response("locations" => { "nodes" => [ { "id" => "gid://shopify/Location/1" } ] }),
        # inventoryItemUpdate
        shopify_response("inventoryItemUpdate" => {
          "inventoryItem" => { "id" => "gid://shopify/InventoryItem/123", "tracked" => true },
          "userErrors" => []
        }),
        # inventorySetQuantities
        shopify_response("inventorySetQuantities" => {
          "inventoryAdjustmentGroup" => { "reason" => "correction" },
          "userErrors" => []
        })
      ]

      stub_shopify_api(responses: responses) do
        ShopifySync::InventorySyncer.new.call(product)
      end

      assert_not_nil product.reload.shopify_synced_at
    end

    test "skips products without an inventory item id" do
      product = products(:dragon_shield_red)
      product.update!(sync_to_shopify: true, shopify_inventory_item_id: nil)

      stub_shopify_api do
        # No API calls expected — passing an empty queue, any stray call returns empty success
        ShopifySync::InventorySyncer.new.call(product)
      end

      assert_nil product.reload.shopify_synced_at
    end

    test "raises when no shopify location is found" do
      product = products(:dragon_shield_red)
      product.update!(sync_to_shopify: true, shopify_inventory_item_id: "gid://shopify/InventoryItem/123")

      responses = [
        shopify_response("locations" => { "nodes" => [] })
      ]

      stub_shopify_api(responses: responses) do
        assert_raises(RuntimeError, /No Shopify location found/) do
          ShopifySync::InventorySyncer.new.call(product)
        end
      end
    end
  end
end
