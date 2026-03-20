# frozen_string_literal: true

module ShopifySync
  # Adjusts the Shopify available inventory quantity when items are added to or
  # removed from a local order.
  #
  # A positive delta means items were added to an order (reduces available stock).
  # A negative delta means items were removed from an order (restores available stock).
  class CommittedSyncer < Base
    def call(product, delta)
      return unless product.sync_to_shopify? && product.shopify_inventory_item_id.present?
      return if delta == 0

      response = graphql_client.query(
        query: inventory_adjust_mutation,
        variables: {
          input: {
            reason: "correction",
            name: "available",
            changes: [
              {
                inventoryItemId: product.shopify_inventory_item_id,
                locationId: primary_location_id,
                delta: -delta
              }
            ]
          }
        }
      )

      extract_data!(response, "inventoryAdjustQuantities")
    end

    private

      def primary_location_id
        @primary_location_id ||= begin
          response = graphql_client.query(query: location_query)
          response.body.dig("data", "locations", "nodes", 0, "id")
        end
      end

      def inventory_adjust_mutation
        <<~GRAPHQL
          mutation inventoryAdjustQuantities($input: InventoryAdjustQuantitiesInput!) {
            inventoryAdjustQuantities(input: $input) {
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
