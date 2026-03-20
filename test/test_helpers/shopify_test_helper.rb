# frozen_string_literal: true

module ShopifyTestHelper
  # A sequential stub client — responses are consumed from a queue in order.
  # Any call beyond the queued responses returns a generic empty success.
  class StubGraphqlClient
    EMPTY_SUCCESS = OpenStruct.new(body: { "data" => {}, "errors" => nil }).freeze

    def initialize(responses)
      @queue = Array(responses).dup
    end

    def query(**_kwargs)
      @queue.shift || EMPTY_SUCCESS
    end
  end

  # Fake Net::HTTP response that satisfies the token-fetch check in Base#fetch_access_token.
  FakeTokenResponse = Struct.new(:body) do
    def is_a?(klass)
      klass == Net::HTTPSuccess || super
    end
  end

  # Builds a fake GraphQL response envelope with the given data payload.
  def shopify_response(data)
    OpenStruct.new(body: { "data" => data, "errors" => nil })
  end

  # Stubs all Shopify network calls for the duration of the given block.
  #
  # Pass `responses:` as an ordered array of shopify_response(...) values.
  # All ShopifyAPI::Clients::Graphql::Admin instances created within the block
  # share a single StubGraphqlClient that drains the queue in call order.
  #
  # Usage:
  #   stub_shopify_api(responses: [shopify_response("productSet" => {...}), ...]) do
  #     ShopifySync::ProductPusher.new.call(product)
  #   end
  def stub_shopify_api(responses: [], &block)
    fake_creds = { shop_domain: "test.myshopify.com", client_id: "fake_id", client_secret: "fake_secret" }
    fake_token_response = FakeTokenResponse.new('{"access_token":"fake_token"}')
    stub_client = StubGraphqlClient.new(responses)

    # Clear any real token that might be cached from a previous test or dev run.
    Rails.cache.delete("shopify_sync/access_token")

    Rails.application.credentials.stub(:dig, ->(*args) { args == [ :shopify ] ? fake_creds : nil }) do
      Net::HTTP.stub(:post_form, fake_token_response) do
        ShopifyAPI::Context.stub(:activate_session, nil) do
          ShopifyAPI::Context.stub(:deactivate_session, nil) do
            ShopifyAPI::Clients::Graphql::Admin.stub(:new, stub_client) do
              block.call
            end
          end
        end
      end
    end
  end
end
