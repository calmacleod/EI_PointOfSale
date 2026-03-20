# frozen_string_literal: true

require "test_helper"

module ShopifySync
  class ProductPusherTest < ActiveSupport::TestCase
    test "raises when shopify credentials are not configured" do
      product = products(:dragon_shield_red)
      product.update!(sync_to_shopify: true)

      Rails.application.credentials.stub(:dig, ->(*) { nil }) do
        assert_raises(RuntimeError, /Shopify credentials not configured/) do
          ShopifySync::ProductPusher.new.call(product)
        end
      end
    end

    test "pushes standalone product and persists shopify ids" do
      product = products(:dragon_shield_red)
      product.update!(sync_to_shopify: true)

      responses = [
        # productSet mutation
        shopify_response("productSet" => {
          "product" => {
            "id" => "gid://shopify/Product/100",
            "variants" => { "nodes" => [
              { "id" => "gid://shopify/ProductVariant/200", "inventoryItem" => { "id" => "gid://shopify/InventoryItem/300" } }
            ] }
          },
          "userErrors" => []
        }),
        # metafieldsSet mutation
        shopify_response("metafieldsSet" => { "metafields" => [], "userErrors" => [] }),
        # InventorySyncer — locations query
        shopify_response("locations" => { "nodes" => [ { "id" => "gid://shopify/Location/1" } ] }),
        # InventorySyncer — inventoryItemUpdate
        shopify_response("inventoryItemUpdate" => {
          "inventoryItem" => { "id" => "gid://shopify/InventoryItem/300", "tracked" => true },
          "userErrors" => []
        }),
        # InventorySyncer — inventorySetQuantities
        shopify_response("inventorySetQuantities" => {
          "inventoryAdjustmentGroup" => { "reason" => "correction" },
          "userErrors" => []
        })
      ]

      stub_shopify_api(responses: responses) do
        ShopifySync::ProductPusher.new.call(product)
      end

      product.reload
      assert_equal "gid://shopify/Product/100", product.shopify_product_id
      assert_equal "gid://shopify/ProductVariant/200", product.shopify_variant_id
      assert_equal "gid://shopify/InventoryItem/300", product.shopify_inventory_item_id
      assert_not_nil product.shopify_synced_at
    end

    test "pushes grouped product and persists shopify ids on each sibling" do
      group = ProductGroup.create!(name: "Dragon Shield Matte Sleeves")
      product = products(:dragon_shield_red)
      product.update!(product_group: group, sync_to_shopify: true)

      responses = [
        # productSet mutation for the group
        shopify_response("productSet" => {
          "product" => {
            "id" => "gid://shopify/Product/500",
            "variants" => { "nodes" => [
              { "id" => "gid://shopify/ProductVariant/600", "inventoryItem" => { "id" => "gid://shopify/InventoryItem/700" } }
            ] }
          },
          "userErrors" => []
        }),
        # metafieldsSet mutation
        shopify_response("metafieldsSet" => { "metafields" => [], "userErrors" => [] }),
        # InventorySyncer — locations query
        shopify_response("locations" => { "nodes" => [ { "id" => "gid://shopify/Location/1" } ] }),
        # InventorySyncer — inventoryItemUpdate
        shopify_response("inventoryItemUpdate" => {
          "inventoryItem" => { "id" => "gid://shopify/InventoryItem/700", "tracked" => true },
          "userErrors" => []
        }),
        # InventorySyncer — inventorySetQuantities
        shopify_response("inventorySetQuantities" => {
          "inventoryAdjustmentGroup" => { "reason" => "correction" },
          "userErrors" => []
        })
      ]

      stub_shopify_api(responses: responses) do
        ShopifySync::ProductPusher.new.call(product)
      end

      assert_equal "gid://shopify/Product/500", group.reload.shopify_product_id
      product.reload
      assert_equal "gid://shopify/Product/500", product.shopify_product_id
      assert_equal "gid://shopify/ProductVariant/600", product.shopify_variant_id
    end

    test "raises when productSet returns user errors" do
      product = products(:dragon_shield_red)
      product.update!(sync_to_shopify: true)

      responses = [
        shopify_response("productSet" => {
          "product" => nil,
          "userErrors" => [ { "field" => "title", "message" => "Title can't be blank" } ]
        })
      ]

      stub_shopify_api(responses: responses) do
        assert_raises(RuntimeError, /Shopify API error/) do
          ShopifySync::ProductPusher.new.call(product)
        end
      end
    end
  end
end
