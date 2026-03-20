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
        products.each do |p|
          puts "Syncing Inventory for #{p.code} (Shopify Item ID: #{p.shopify_inventory_item_id})"
          sync_inventory_for(p)
        end
      end
    end

    private

      def sync_inventory_for(product)
        location_id = primary_location_id
        puts "  Location ID: #{location_id.inspect}"
        raise "No Shopify location found — cannot set inventory" unless location_id
        puts "  Stock level: #{product.stock_level}"

        tracking_response = enable_tracking(product)
        puts "  Enable tracking response: #{tracking_response.body.to_json}"

        variables = {
          input: {
            reason: "correction",
            name: "available",
            ignoreCompareQuantity: true,
            quantities: [
              {
                inventoryItemId: product.shopify_inventory_item_id,
                locationId: location_id,
                quantity: product.stock_level
              }
            ]
          }
        }
        puts "  inventorySetQuantities variables: #{variables.to_json}"

        response = graphql_client.query(
          query: inventory_adjust_mutation,
          variables: variables
        )

        puts "  inventorySetQuantities response: #{response.body.to_json}"

        extract_data!(response, "inventorySetQuantities")
        product.update_column(:shopify_synced_at, Time.current)
      end

      def enable_tracking(product)
        graphql_client.query(
          query: inventory_item_update_mutation,
          variables: {
            id: product.shopify_inventory_item_id,
            input: { tracked: true }
          }
        )
      end

      def inventory_item_update_mutation
        <<~GRAPHQL
          mutation inventoryItemUpdate($id: ID!, $input: InventoryItemInput!) {
            inventoryItemUpdate(id: $id, input: $input) {
              inventoryItem {
                id
                tracked
              }
              userErrors {
                field
                message
              }
            }
          }
        GRAPHQL
      end

      def primary_location_id
        @primary_location_id ||= begin
          response = graphql_client.query(query: location_query)
          puts "  Location query response: #{response.body.to_json}"
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
              }
            }
          }
        GRAPHQL
      end
  end
end
