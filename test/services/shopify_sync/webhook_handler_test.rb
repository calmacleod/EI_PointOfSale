# frozen_string_literal: true

require "test_helper"

module ShopifySync
  class WebhookHandlerTest < ActiveSupport::TestCase
    test "handles orders/create and decrements stock" do
      product = products(:dragon_shield_red)
      product.update!(
        shopify_variant_id: "gid://shopify/ProductVariant/12345",
        stock_level: 20
      )

      payload = {
        "line_items" => [
          {
            "variant_id" => 12345,
            "quantity" => 3
          }
        ]
      }

      ShopifySync::WebhookHandler.new.call(topic: "orders/create", payload: payload)

      assert_equal 17, product.reload.stock_level
    end

    test "handles orders/create with unknown variant gracefully" do
      payload = {
        "line_items" => [
          {
            "variant_id" => 99999,
            "quantity" => 1
          }
        ]
      }

      assert_nothing_raised do
        ShopifySync::WebhookHandler.new.call(topic: "orders/create", payload: payload)
      end
    end

    test "handles unknown webhook topics gracefully" do
      assert_nothing_raised do
        ShopifySync::WebhookHandler.new.call(topic: "unknown/topic", payload: {})
      end
    end

    test "stock does not go below zero" do
      product = products(:nhl_puck)
      product.update!(
        shopify_variant_id: "gid://shopify/ProductVariant/99999",
        stock_level: 2
      )

      payload = {
        "line_items" => [
          {
            "variant_id" => 99999,
            "quantity" => 5
          }
        ]
      }

      ShopifySync::WebhookHandler.new.call(topic: "orders/create", payload: payload)

      assert_equal 0, product.reload.stock_level
    end
  end
end
