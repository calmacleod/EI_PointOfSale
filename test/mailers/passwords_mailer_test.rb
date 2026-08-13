# frozen_string_literal: true

require "test_helper"

class PasswordsMailerTest < ActionMailer::TestCase
  test "reset email uses configured app host" do
    original_options = ActionMailer::Base.default_url_options
    ActionMailer::Base.default_url_options = { host: "pos.callummacleod.ca", protocol: "https" }

    mail = PasswordsMailer.reset(users(:admin))

    assert_includes mail.body.encoded, "https://pos.callummacleod.ca/passwords/"
    assert_includes mail.body.encoded, "https://pos.callummacleod.ca/assets/brand/ei-mark-"
  ensure
    ActionMailer::Base.default_url_options = original_options
  end
end
