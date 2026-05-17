# frozen_string_literal: true

require "test_helper"

class ShopifyWebhooksControllerTest < ActionDispatch::IntegrationTest
  include ActiveJob::TestHelper

  setup do
    clear_enqueued_jobs
  end

  teardown do
    clear_enqueued_jobs
  end

  test "accepts valid HMAC webhook without authentication" do
    body = { "id" => 123, "admin_graphql_api_id" => "gid://shopify/Product/123" }.to_json
    topic = "products/update"

    with_shopify_secret("shh") do
      assert_enqueued_jobs 1, only: ShopifySync::ProcessWebhookJob do
        post shopify_webhooks_path,
             params: body,
             headers: webhook_headers(body, topic: topic, secret: "shh")
      end
    end

    assert_response :ok
  end

  test "rejects missing HMAC without enqueueing a job" do
    body = { "id" => 123 }.to_json

    with_shopify_secret("shh") do
      assert_no_enqueued_jobs only: ShopifySync::ProcessWebhookJob do
        post shopify_webhooks_path,
             params: body,
             headers: { "CONTENT_TYPE" => "application/json", "X-Shopify-Topic" => "products/update" }
      end
    end

    assert_response :unauthorized
  end

  test "rejects invalid HMAC without enqueueing a job" do
    body = { "id" => 123 }.to_json

    with_shopify_secret("shh") do
      assert_no_enqueued_jobs only: ShopifySync::ProcessWebhookJob do
        post shopify_webhooks_path,
             params: body,
             headers: webhook_headers(body, topic: "products/update", secret: "wrong")
      end
    end

    assert_response :unauthorized
  end

  test "returns unprocessable entity for invalid JSON after HMAC passes" do
    body = "{not-json"

    with_shopify_secret("shh") do
      assert_no_enqueued_jobs only: ShopifySync::ProcessWebhookJob do
        post shopify_webhooks_path,
             params: body,
             headers: webhook_headers(body, topic: "products/update", secret: "shh")
      end
    end

    assert_response :unprocessable_entity
  end

  test "rejects webhooks when Shopify secret is not configured" do
    body = { "id" => 123 }.to_json

    with_shopify_secret(nil) do
      assert_no_enqueued_jobs only: ShopifySync::ProcessWebhookJob do
        post shopify_webhooks_path,
             params: body,
             headers: webhook_headers(body, topic: "products/update", secret: "shh")
      end
    end

    assert_response :unauthorized
  end

  private

    def webhook_headers(body, topic:, secret:)
      {
        "CONTENT_TYPE" => "application/json",
        "X-Shopify-Topic" => topic,
        "X-Shopify-Hmac-SHA256" => Base64.strict_encode64(OpenSSL::HMAC.digest("sha256", secret, body))
      }
    end

    def with_shopify_secret(secret, &block)
      Rails.application.credentials.stub(:dig, ->(*args) {
        args == [ :shopify, :client_secret ] ? secret : nil
      }, &block)
    end
end
