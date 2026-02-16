# frozen_string_literal: true

module ShopifySync
  # Pulls product data from Shopify and updates local records.
  # Used for initial import of existing Shopify products.
  class ProductPuller < Base
    def call
      with_shopify_session do
        cursor = nil
        loop do
          response = graphql_client.query(
            query: products_query,
            variables: { cursor: cursor }
          )

          products_data = response.body.dig("data", "products")
          break unless products_data

          products_data["nodes"].each do |shopify_product|
            sync_product(shopify_product)
          end

          page_info = products_data["pageInfo"]
          break unless page_info["hasNextPage"]
          cursor = page_info["endCursor"]
        end
      end
    end

    private

      def sync_product(shopify_product)
        shopify_product_id = shopify_product["id"]
        variants = shopify_product.dig("variants", "nodes") || []

        variants.each do |variant|
          sku = variant["sku"].presence
          next unless sku

          product = Product.find_by(code: sku) || Product.new(code: sku)
          product.assign_attributes(
            name: product.new_record? ? shopify_product["title"] : product.name,
            selling_price: variant["price"]&.to_d,
            shopify_product_id: shopify_product_id,
            shopify_variant_id: variant["id"],
            shopify_inventory_item_id: variant.dig("inventoryItem", "id"),
            sync_to_shopify: true,
            shopify_synced_at: Time.current
          )
          product.save!
        rescue => e
          Rails.logger.error("Failed to pull Shopify product #{shopify_product_id}: #{e.message}")
        end
      end

      def products_query
        <<~GRAPHQL
          query($cursor: String) {
            products(first: 50, after: $cursor) {
              nodes {
                id
                title
                productType
                variants(first: 100) {
                  nodes {
                    id
                    sku
                    price
                    barcode
                    inventoryItem {
                      id
                    }
                  }
                }
              }
              pageInfo {
                hasNextPage
                endCursor
              }
            }
          }
        GRAPHQL
      end
  end
end
