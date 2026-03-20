# frozen_string_literal: true

# Shopify API Configuration
#
# Store your credentials in Rails encrypted credentials:
#
#   bin/rails credentials:edit
#
# Add the following block:
#
#   shopify:
#     shop_domain: "yourstore.myshopify.com"
#     client_id: "your-client-id"
#     client_secret: "your-client-secret"
#     api_version: "2026-01"
#
# === How to get your Shopify API credentials ===
#
# 1. Go to https://partners.shopify.com/ and open your Dev Dashboard
# 2. Click "Create app" and name it (e.g., "EI POS Integration")
# 3. Under Configuration > API access, set Admin API scopes:
#    - read_products, write_products
#    - read_inventory, write_inventory
#    - read_orders
# 4. Install the app on your store
# 5. Copy the Client ID and Client secret from the app's overview page
#

shopify_creds = Rails.application.credentials.dig(:shopify)

if shopify_creds.present? && shopify_creds[:shop_domain].present?
  ShopifyAPI::Context.setup(
    api_key: shopify_creds[:client_id],
    api_secret_key: shopify_creds[:client_secret],
    host_name: shopify_creds[:shop_domain],
    scope: "read_products,write_products,read_inventory,write_inventory,read_orders",
    is_embedded: false,
    is_private: true,
    api_version: shopify_creds[:api_version] || "2026-01"
  )
end
