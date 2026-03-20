# frozen_string_literal: true

module ShopifySync
  class Base
    private

      def shopify_session
        creds = Rails.application.credentials.dig(:shopify)
        raise "Shopify credentials not configured" unless creds&.dig(:shop_domain).present?

        access_token = fetch_access_token(creds)

        ShopifyAPI::Auth::Session.new(
          shop: creds[:shop_domain],
          access_token: access_token
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

      def extract_data!(response, mutation_name)
        body = response.body

        if body["errors"].present?
          messages = Array(body["errors"]).map { |e| e.is_a?(Hash) ? e["message"] : e.to_s }.join(", ")
          raise "Shopify GraphQL error: #{messages}"
        end

        data = body.dig("data", mutation_name)
        raise "Shopify returned no data for #{mutation_name}" unless data

        user_errors = data["userErrors"]
        if user_errors.present?
          messages = user_errors.map { |e| e["message"] }.join(", ")
          raise "Shopify API error: #{messages}"
        end

        data
      end

      # Obtains an access token via the Client Credentials Grant.
      # Tokens are cached for 23 hours (they expire after 24h).
      def fetch_access_token(creds)
        raise "Shopify client_id not configured" unless creds[:client_id].present?
        raise "Shopify client_secret not configured" unless creds[:client_secret].present?

        Rails.cache.fetch("shopify_sync/access_token", expires_in: 23.hours) do
          uri = URI("https://#{creds[:shop_domain]}/admin/oauth/access_token")
          response = Net::HTTP.post_form(uri, {
            "grant_type" => "client_credentials",
            "client_id" => creds[:client_id],
            "client_secret" => creds[:client_secret]
          })

          body = JSON.parse(response.body)

          unless response.is_a?(Net::HTTPSuccess)
            raise "Shopify token request failed: #{body['error_description'] || body['error'] || response.code}"
          end

          body.fetch("access_token")
        end
      end
  end
end
