ENV["RAILS_ENV"] ||= "test"
require_relative "../config/environment"
require "rails/test_help"
require "minitest/mock"
require "minitest/reporters"
require "minitest/minitest_reporter_plugin"
require "webmock/minitest"

Minitest.register_plugin :minitest_reporter
Minitest::Reporters.use! [ Minitest::Reporters::DefaultReporter.new(detailed_skip: false) ]

# Block all outgoing network requests. Any test that needs to simulate an HTTP
# interaction must stub the call explicitly (e.g. via WebMock.stub_request or
# the ShopifyTestHelper#stub_shopify_api helper).
WebMock.disable_net_connect!(allow_localhost: true)

require_relative "test_helpers/session_test_helper"
require_relative "test_helpers/turbo_stream_test_helper"
require_relative "test_helpers/shopify_test_helper"

module ActiveSupport
  class TestCase
    include ShopifyTestHelper

    # Run tests in parallel (single worker in CI for JUnit report)
    parallelize(workers: :number_of_processors)

    # Setup all fixtures in test/fixtures/*.yml for all tests in alphabetical order.
    fixtures :all

    # 1x1 transparent PNG (68 bytes) used to stub browser-based chart rendering in tests.
    DUMMY_PNG = Base64.decode64(
      "iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAYAAAAfFcSJAAAAC0lEQVQI12NgAAIABQAB" \
      "Nl7BcQAAAABJRU5ErkJggg=="
    ).freeze
  end
end
