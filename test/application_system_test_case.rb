require "test_helper"
require_relative "test_helpers/system_session_helper"

class ApplicationSystemTestCase < ActionDispatch::SystemTestCase
  driven_by :selenium, using: :headless_chrome, screen_size: [ 1400, 1400 ]

  include SystemSessionHelper
end
