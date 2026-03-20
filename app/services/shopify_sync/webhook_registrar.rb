# frozen_string_literal: true

module ShopifySync
  # Registers webhook subscriptions with Shopify via the Admin GraphQL API.
  # Idempotent: Shopify deduplicates subscriptions by topic + callbackUrl.
  class WebhookRegistrar < Base
    TOPICS = %w[orders/paid].freeze

    MUTATION = <<~GRAPHQL
      mutation webhookSubscriptionCreate($topic: WebhookSubscriptionTopic!, $webhookSubscription: WebhookSubscriptionInput!) {
        webhookSubscriptionCreate(topic: $topic, webhookSubscription: $webhookSubscription) {
          webhookSubscription {
            id
            topic
            endpoint {
              ... on WebhookHttpEndpoint {
                callbackUrl
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

    def call
      client = graphql_client
      TOPICS.each { |topic| register(client, topic) }
    end

    private

      def register(client, topic)
        callback_url = "#{app_url}/shopify/webhooks"
        graphql_topic = topic.upcase.tr("/", "_")

        response = client.query(
          query: MUTATION,
          variables: {
            topic: graphql_topic,
            webhookSubscription: { callbackUrl: callback_url, format: "JSON" }
          }
        )

        data = extract_data!(response, "webhookSubscriptionCreate")
        endpoint = data.dig("webhookSubscription", "endpoint", "callbackUrl")

        Rails.logger.info("ShopifySync::WebhookRegistrar: registered #{topic} → #{endpoint}")
      end

      def app_url
        url = Rails.application.credentials.dig(:shopify, :app_url) || ENV["APP_URL"]
        raise "Configure shopify.app_url credential or APP_URL env var for webhook registration" unless url.present?

        url.chomp("/")
      end
  end
end
