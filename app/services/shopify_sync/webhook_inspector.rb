# frozen_string_literal: true

module ShopifySync
  # Fetches registered webhook subscriptions from the Shopify Admin API.
  # Returns an array of hashes with :id, :topic, :callback_url, :created_at.
  class WebhookInspector < Base
    QUERY = <<~GRAPHQL
      {
        webhookSubscriptions(first: 50) {
          nodes {
            id
            topic
            createdAt
            updatedAt
            endpoint {
              ... on WebhookHttpEndpoint {
                callbackUrl
              }
            }
          }
        }
      }
    GRAPHQL

    def call
      response = graphql_client.query(query: QUERY)
      nodes = response.body.dig("data", "webhookSubscriptions", "nodes") || []

      nodes.map do |node|
        {
          id: node["id"],
          topic: node["topic"],
          callback_url: node.dig("endpoint", "callbackUrl"),
          created_at: node["createdAt"]&.then { |t| Time.zone.parse(t) },
          updated_at: node["updatedAt"]&.then { |t| Time.zone.parse(t) }
        }
      end
    end
  end
end
