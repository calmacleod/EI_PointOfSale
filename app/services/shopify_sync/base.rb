# frozen_string_literal: true

module ShopifySync
  class Base
    private

      def shopify_session
        creds = Rails.application.credentials.dig(:shopify)
        raise "Shopify credentials not configured" unless creds&.dig(:shop_domain).present?

        ShopifyAPI::Auth::Session.new(
          shop: creds[:shop_domain],
          access_token: creds[:access_token]
        )
      end

      def with_shopify_session(&block)
        session = shopify_session
        ShopifyAPI::Context.activate_session(session)
        yield session
      ensure
        ShopifyAPI::Context.deactivate_session
      end

      def graphql_client
        ShopifyAPI::Clients::Graphql::Admin.new(session: shopify_session)
      end
  end
end
