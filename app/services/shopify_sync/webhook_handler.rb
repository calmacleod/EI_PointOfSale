# frozen_string_literal: true

module ShopifySync
  # Processes incoming Shopify webhooks.
  # Currently handles orders/create to decrement local stock on in-store pickup.
  class WebhookHandler < Base
    def call(topic:, payload:)
      case topic
      when "orders/create"
        handle_order_created(payload)
      when "orders/paid"
        handle_order_paid(payload)
      when "products/update"
        handle_product_updated(payload)
      else
        Rails.logger.info("Unhandled Shopify webhook topic: #{topic}")
      end
    end

    private

      def handle_order_paid(payload)
        order_number = payload["order_number"] || payload["name"]
        line_items = payload["line_items"] || []

        quantities = line_items.filter_map do |item|
          variant_id = "gid://shopify/ProductVariant/#{item['variant_id']}"
          product = Product.find_by(shopify_variant_id: variant_id)
          next unless product

          quantity = item["quantity"].to_i
          new_stock = [ product.stock_level - quantity, 0 ].max
          product.update!(stock_level: new_stock)

          { code: product.code, name: product.name, quantity: quantity, stock_after: new_stock }
        end

        Rails.logger.info(
          "Shopify orders/paid ##{order_number}: " \
          "#{quantities.map { |q| "#{q[:code]} ×#{q[:quantity]}" }.join(', ')}"
        )
      end

      def handle_order_created(payload)
        line_items = payload["line_items"] || []

        line_items.each do |item|
          variant_id = "gid://shopify/ProductVariant/#{item['variant_id']}"
          product = Product.find_by(shopify_variant_id: variant_id)
          next unless product

          quantity = item["quantity"].to_i
          new_stock = [ product.stock_level - quantity, 0 ].max
          product.update!(stock_level: new_stock)

          Rails.logger.info(
            "Shopify order: decremented #{product.code} stock by #{quantity} (now #{new_stock})"
          )
        end
      end

      def handle_product_updated(payload)
        shopify_product_id = "gid://shopify/Product/#{payload['id']}"
        products = Product.where(shopify_product_id: shopify_product_id)

        return if products.empty?

        variants = payload["variants"] || []
        variants.each do |variant|
          variant_id = "gid://shopify/ProductVariant/#{variant['id']}"
          product = products.find_by(shopify_variant_id: variant_id)
          next unless product

          product.update!(
            selling_price: variant["price"]&.to_d,
            shopify_synced_at: Time.current
          )
        end
      end
  end
end
