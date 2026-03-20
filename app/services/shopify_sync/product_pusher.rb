# frozen_string_literal: true

module ShopifySync
  # Pushes a product (or product group) to Shopify via the Admin GraphQL API.
  # Uses the `productSet` mutation (2024-01+) which handles both create and
  # update in a single call, including variants.
  class ProductPusher < Base
    def call(product)
      if product.product_group.present?
        push_grouped_product(product)
      else
        push_standalone_product(product)
      end
    end

    private

      def push_standalone_product(product)
        with_shopify_session do
          response = graphql_client.query(
            query: product_set_mutation,
            variables: { input: product_set_input(product) }
          )

          data = extract_data!(response, "productSet")
          shopify_product = data["product"]
          shopify_variant = shopify_product.dig("variants", "nodes", 0)

          product.update!(
            shopify_product_id: shopify_product["id"],
            shopify_variant_id: shopify_variant&.dig("id"),
            shopify_inventory_item_id: shopify_variant&.dig("inventoryItem", "id"),
            shopify_synced_at: Time.current
          )

          sync_image(shopify_product["id"], product)
          sync_inventory(product)
        end
      end

      def push_grouped_product(product)
        group = product.product_group
        siblings = group.products.where(sync_to_shopify: true).order(:id)

        with_shopify_session do
          input = {
            title: group.name,
            productOptions: [ { name: "Title", values: siblings.map { |p| { name: p.name } } } ],
            variants: siblings.map { |p| variant_input(p, option_name: p.name) }
          }
          input[:id] = group.shopify_product_id if group.shopify_product_id.present?

          response = graphql_client.query(
            query: product_set_mutation,
            variables: { input: input }
          )

          data = extract_data!(response, "productSet")
          shopify_product = data["product"]
          group.update!(shopify_product_id: shopify_product["id"])

          shopify_variants = shopify_product.dig("variants", "nodes") || []
          siblings.each_with_index do |sib, i|
            sv = shopify_variants[i]
            next unless sv

            sib.update!(
              shopify_product_id: shopify_product["id"],
              shopify_variant_id: sv["id"],
              shopify_inventory_item_id: sv.dig("inventoryItem", "id"),
              shopify_synced_at: Time.current
            )
          end

          image_product = siblings.detect { |s| s.images.attached? } || siblings.first
          sync_image(shopify_product["id"], image_product)
          siblings.each { |sib| sync_inventory(sib) }
        end
      end

      def product_set_input(product)
        input = {
          title: product.name,
          productType: product.categories.first&.name || "",
          productOptions: [ { name: "Title", values: [ { name: "Default Title" } ] } ],
          variants: [ variant_input(product) ]
        }
        input[:id] = product.shopify_product_id if product.shopify_product_id.present?
        input
      end

      def variant_input(product, option_name: nil)
        v = {
          price: product.selling_price&.to_s,
          sku: product.code,
          barcode: product.code,
          inventoryItem: { tracked: true },
          optionValues: [ { name: option_name || "Default Title", optionName: "Title" } ]
        }
        v[:id] = product.shopify_variant_id if product.shopify_variant_id.present?
        v
      end

      def sync_inventory(product)
        return unless product.shopify_inventory_item_id.present?

        InventorySyncer.new.call(product)
      end

      def sync_image(shopify_product_id, product)
        return unless product.images.attached?

        image = product.images.first
        image_url = image.url

        graphql_client.query(
          query: product_create_media_mutation,
          variables: {
            productId: shopify_product_id,
            media: [ { originalSource: image_url, mediaContentType: "IMAGE" } ]
          }
        )
      end

      def product_create_media_mutation
        <<~GRAPHQL
          mutation productCreateMedia($productId: ID!, $media: [CreateMediaInput!]!) {
            productCreateMedia(productId: $productId, media: $media) {
              media {
                ... on MediaImage {
                  id
                }
              }
              mediaUserErrors {
                field
                message
              }
            }
          }
        GRAPHQL
      end

      def product_set_mutation
        <<~GRAPHQL
          mutation productSet($input: ProductSetInput!) {
            productSet(input: $input) {
              product {
                id
                title
                variants(first: 50) {
                  nodes {
                    id
                    inventoryItem {
                      id
                    }
                  }
                }
              }
              userErrors {
                field
                message
              }
            }
          }
        GRAPHQL
      end
  end
end
