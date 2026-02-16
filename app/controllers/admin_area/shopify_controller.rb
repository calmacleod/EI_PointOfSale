# frozen_string_literal: true

module AdminArea
  class ShopifyController < ApplicationController
    before_action :require_admin

    def show
      @configured = shopify_configured?
      @synced_count = Product.kept.where(sync_to_shopify: true).count
      @last_synced = Product.kept.where.not(shopify_synced_at: nil).maximum(:shopify_synced_at)
    end

    def sync_all
      products = Product.kept.where(sync_to_shopify: true)
      products.find_each do |product|
        ShopifySync::PushProductJob.perform_later(product.id)
      end
      ShopifySync::SyncInventoryJob.perform_later

      redirect_to admin_shopify_path, notice: "Sync jobs enqueued for #{products.count} products."
    end

    def test_connection
      if !shopify_configured?
        redirect_to admin_shopify_path, alert: "Shopify credentials are not configured."
        return
      end

      creds = Rails.application.credentials.dig(:shopify)
      session = ShopifyAPI::Auth::Session.new(
        shop: creds[:shop_domain],
        access_token: creds[:access_token]
      )
      ShopifyAPI::Context.activate_session(session)

      client = ShopifyAPI::Clients::Graphql::Admin.new(session: session)
      response = client.query(query: "{ shop { name myshopifyDomain } }")
      shop_data = response.body.dig("data", "shop")

      if shop_data
        redirect_to admin_shopify_path, notice: "Connected to #{shop_data['name']} (#{shop_data['myshopifyDomain']})."
      else
        redirect_to admin_shopify_path, alert: "Connection failed. Check your credentials."
      end
    rescue => e
      redirect_to admin_shopify_path, alert: "Connection error: #{e.message}"
    ensure
      ShopifyAPI::Context.deactivate_session
    end

    private

      def shopify_configured?
        creds = Rails.application.credentials.dig(:shopify)
        creds.present? && creds[:shop_domain].present? && creds[:access_token].present?
      end

      def require_admin
        redirect_to root_path, alert: "Not authorized." unless current_user&.is_a?(Admin)
      end
  end
end
