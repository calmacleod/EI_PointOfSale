# frozen_string_literal: true

module ShopifySync
  # Pushes a product (or product group) to Shopify via the Admin GraphQL API.
  # Creates or updates the Shopify product + variant(s) and stores the returned
  # GIDs back on the local record.
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
          if product.shopify_product_id.present?
            update_shopify_product(product)
          else
            create_shopify_product(product)
          end
        end
      end

      def push_grouped_product(product)
        group = product.product_group
        siblings = group.products.where(sync_to_shopify: true).order(:id)

        with_shopify_session do
          if group.shopify_product_id.present?
            update_grouped_shopify_product(group, siblings)
          else
            create_grouped_shopify_product(group, siblings)
          end
        end
      end

      def create_shopify_product(product)
        response = graphql_client.query(
          query: product_create_mutation,
          variables: {
            input: {
              title: product.name,
              productType: product.categories.first&.name || "",
              variants: [ variant_input(product) ]
            }
          }
        )

        data = response.body.dig("data", "productCreate")
        handle_user_errors!(data)

        shopify_product = data["product"]
        shopify_variant = shopify_product.dig("variants", "nodes", 0)

        product.update!(
          shopify_product_id: shopify_product["id"],
          shopify_variant_id: shopify_variant&.dig("id"),
          shopify_inventory_item_id: shopify_variant&.dig("inventoryItem", "id"),
          shopify_synced_at: Time.current
        )
      end

      def update_shopify_product(product)
        response = graphql_client.query(
          query: product_update_mutation,
          variables: {
            input: {
              id: product.shopify_product_id,
              title: product.name,
              productType: product.categories.first&.name || ""
            }
          }
        )

        data = response.body.dig("data", "productUpdate")
        handle_user_errors!(data)

        if product.shopify_variant_id.present?
          update_shopify_variant(product)
        end

        product.update!(shopify_synced_at: Time.current)
      end

      def update_shopify_variant(product)
        graphql_client.query(
          query: variant_update_mutation,
          variables: {
            input: {
              id: product.shopify_variant_id,
              price: product.selling_price&.to_s,
              sku: product.code,
              barcode: product.code
            }
          }
        )
      end

      def create_grouped_shopify_product(group, products)
        response = graphql_client.query(
          query: product_create_mutation,
          variables: {
            input: {
              title: group.name,
              variants: products.map { |p| variant_input(p) }
            }
          }
        )

        data = response.body.dig("data", "productCreate")
        handle_user_errors!(data)

        shopify_product = data["product"]
        group.update!(shopify_product_id: shopify_product["id"])

        shopify_variants = shopify_product.dig("variants", "nodes") || []
        products.each_with_index do |product, i|
          sv = shopify_variants[i]
          next unless sv

          product.update!(
            shopify_product_id: shopify_product["id"],
            shopify_variant_id: sv["id"],
            shopify_inventory_item_id: sv.dig("inventoryItem", "id"),
            shopify_synced_at: Time.current
          )
        end
      end

      def update_grouped_shopify_product(group, products)
        graphql_client.query(
          query: product_update_mutation,
          variables: {
            input: {
              id: group.shopify_product_id,
              title: group.name
            }
          }
        )

        products.each do |product|
          if product.shopify_variant_id.present?
            update_shopify_variant(product)
          end
          product.update!(shopify_synced_at: Time.current)
        end
      end

      def variant_input(product)
        {
          price: product.selling_price&.to_s,
          sku: product.code,
          barcode: product.code,
          inventoryManagement: "SHOPIFY",
          options: product.name.present? ? [ product.name ] : []
        }
      end

      def handle_user_errors!(data)
        errors = data&.dig("userErrors")
        return if errors.blank?

        messages = errors.map { |e| e["message"] }.join(", ")
        raise "Shopify API error: #{messages}"
      end

      def product_create_mutation
        <<~GRAPHQL
          mutation productCreate($input: ProductInput!) {
            productCreate(input: $input) {
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

      def product_update_mutation
        <<~GRAPHQL
          mutation productUpdate($input: ProductInput!) {
            productUpdate(input: $input) {
              product {
                id
                title
              }
              userErrors {
                field
                message
              }
            }
          }
        GRAPHQL
      end

      def variant_update_mutation
        <<~GRAPHQL
          mutation productVariantUpdate($input: ProductVariantInput!) {
            productVariantUpdate(input: $input) {
              productVariant {
                id
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
