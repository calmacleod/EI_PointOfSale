# frozen_string_literal: true

module ShopifySync
  # Synchronizes stock levels between the local database and Shopify.
  # Uses the Shopify Inventory Level API to adjust quantities.
  class InventorySyncer < Base
    def call(product = nil)
      products = if product
        [ product ].select { |p| p.sync_to_shopify? && p.shopify_inventory_item_id.present? }
      else
        Product.kept.where(sync_to_shopify: true).where.not(shopify_inventory_item_id: nil)
      end

      with_shopify_session do
        products.find_each do |p|
          sync_inventory_for(p)
        end
      end
    end

    private

      def sync_inventory_for(product)
        location_id = primary_location_id
        return unless location_id

        response = graphql_client.query(
          query: inventory_adjust_mutation,
          variables: {
            input: {
              reason: "correction",
              name: "available",
              changes: [
                {
                  delta: 0,
                  inventoryItemId: product.shopify_inventory_item_id,
                  locationId: location_id,
                  quantity: product.stock_level
                }
              ]
            }
          }
        )

        data = response.body.dig("data", "inventorySetQuantities")
        errors = data&.dig("userErrors")
        if errors.present?
          Rails.logger.warn("Shopify inventory sync failed for #{product.code}: #{errors.map { |e| e['message'] }.join(', ')}")
        else
          product.update_column(:shopify_synced_at, Time.current)
        end
      rescue => e
        Rails.logger.error("Shopify inventory sync error for #{product.code}: #{e.message}")
      end

      def primary_location_id
        @primary_location_id ||= begin
          response = graphql_client.query(query: location_query)
          response.body.dig("data", "locations", "nodes", 0, "id")
        end
      end

      def inventory_adjust_mutation
        <<~GRAPHQL
          mutation inventorySetQuantities($input: InventorySetQuantitiesInput!) {
            inventorySetQuantities(input: $input) {
              inventoryAdjustmentGroup {
                reason
              }
              userErrors {
                field
                message
              }
            }
          }
        GRAPHQL
      end

      def location_query
        <<~GRAPHQL
          query {
            locations(first: 1) {
              nodes {
                id
                name
              }
            }
          }
        GRAPHQL
      end
  end
end
