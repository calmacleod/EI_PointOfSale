# frozen_string_literal: true

require "test_helper"

module AdminArea
  class ShopifyControllerTest < ActionDispatch::IntegrationTest
    # Stub WebhookInspector so controller tests never make real Shopify API calls.
    def with_stubbed_webhook_inspector(webhooks: [])
      stub_inspector = ->() { webhooks }
      ShopifySync::WebhookInspector.stub(:new, -> { Object.new.tap { |o| o.define_singleton_method(:call) { webhooks } } }) do
        yield
      end
    end

    test "show renders for admin" do
      sign_in_as(users(:admin))

      with_stubbed_webhook_inspector do
        get admin_shopify_path
      end

      assert_response :success
      assert_includes response.body, "Shopify Integration"
    end

    test "show is not accessible to common users" do
      sign_in_as(users(:one))

      get admin_shopify_path
      assert_redirected_to root_path
    end

    test "show displays setup instructions when not configured" do
      sign_in_as(users(:admin))

      Rails.application.credentials.stub(:dig, ->(*) { nil }) do
        get admin_shopify_path
      end

      assert_response :success
      assert_includes response.body, "Not configured"
      assert_includes response.body, "Setup instructions"
    end

    test "show displays sync count" do
      sign_in_as(users(:admin))
      products(:dragon_shield_red).update!(sync_to_shopify: true)

      with_stubbed_webhook_inspector do
        get admin_shopify_path
      end

      assert_response :success
      assert_includes response.body, "Products to sync"
    end
  end
end
