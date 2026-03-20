# frozen_string_literal: true

# Receives incoming Shopify webhook POST requests.
# Authentication is via HMAC-SHA256 signature verification (X-Shopify-Hmac-SHA256 header).
# Requests are processed asynchronously via ShopifySync::ProcessWebhookJob.
class ShopifyWebhooksController < ApplicationController
  allow_unauthenticated_access
  skip_forgery_protection

  def create
    return head :unauthorized unless valid_hmac?

    topic = request.headers["X-Shopify-Topic"]
    payload = JSON.parse(request.raw_post)

    ShopifySync::ProcessWebhookJob.perform_later(topic: topic, payload: payload)
    head :ok
  rescue JSON::ParserError
    head :unprocessable_entity
  end

  private

    def valid_hmac?
      secret = Rails.application.credentials.dig(:shopify, :client_secret)
      return false unless secret.present?

      hmac_header = request.headers["X-Shopify-Hmac-SHA256"]
      return false unless hmac_header.present?

      expected = Base64.strict_encode64(
        OpenSSL::HMAC.digest("sha256", secret, request.raw_post)
      )

      ActiveSupport::SecurityUtils.secure_compare(expected, hmac_header)
    end
end
