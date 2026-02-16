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
#     api_key: "your-api-key"
#     api_secret: "your-api-secret"
#     access_token: "shpat_xxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx"
#     api_version: "2025-10"
#
# === How to get your Shopify API credentials ===
#
# 1. Go to Shopify Admin > Settings > Apps and sales channels > Develop apps
# 2. Click "Create an app" and name it (e.g., "EI POS Integration")
# 3. Configure Admin API scopes:
#    - read_products, write_products
#    - read_inventory, write_inventory
#    - read_orders
# 4. Install the app to your store
# 5. Copy the Admin API access token (starts with "shpat_")
# 6. Copy the API key and API secret from the app credentials page
#

shopify_creds = Rails.application.credentials.dig(:shopify)

if shopify_creds.present? && shopify_creds[:shop_domain].present?
  ShopifyAPI::Context.setup(
    api_key: shopify_creds[:api_key],
    api_secret_key: shopify_creds[:api_secret],
    host_name: shopify_creds[:shop_domain],
    scope: "read_products,write_products,read_inventory,write_inventory,read_orders",
    is_private: true,
    is_embedded: false,
    api_version: shopify_creds[:api_version] || "2025-10"
  )
end
