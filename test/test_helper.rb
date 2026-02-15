ENV["RAILS_ENV"] ||= "test"
require_relative "../config/environment"
require "rails/test_help"
require "minitest/mock"
require "minitest/reporters"

reporters = [ Minitest::Reporters::DefaultReporter.new ]
if ENV["JUNIT_OUTPUT_DIR"]
  reports_dir = ENV["JUNIT_OUTPUT_DIR"]
  reporters << Minitest::Reporters::JUnitReporter.new(reports_dir, true, single_file: true)
end
Minitest::Reporters.use!(reporters, ENV, Minitest.backtrace_filter)

require_relative "test_helpers/session_test_helper"

module ActiveSupport
  class TestCase
    # Run tests in parallel (single worker in CI for JUnit report)
    parallelize(workers: ENV["JUNIT_OUTPUT_DIR"] ? 1 : :number_of_processors)

    # Setup all fixtures in test/fixtures/*.yml for all tests in alphabetical order.
    fixtures :all

    # Add more helper methods to be used by all tests here...
  end
end
