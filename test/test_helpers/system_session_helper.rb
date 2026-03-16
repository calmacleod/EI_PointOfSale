# frozen_string_literal: true

module SystemSessionHelper
  def system_sign_in_as(user)
    visit new_session_path
    fill_in "Email address", with: user.email_address
    fill_in "Password", with: "password"
    click_button "Sign in"
    # Wait for successful redirect away from login
    assert_no_current_path new_session_path, wait: 5
  end
end
