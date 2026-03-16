ENV["RAILS_ENV"] ||= "test"
require_relative "../config/environment"
require "rails/test_help"
require "minitest/mock"
require "minitest/reporters"

require_relative "test_helpers/session_test_helper"
require_relative "test_helpers/turbo_stream_test_helper"

module ActiveSupport
  class TestCase
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
