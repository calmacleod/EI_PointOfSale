require "application_system_test_case"

class StaffAccessRegressionTest < ApplicationSystemTestCase
  test "rate limited sign-in shows retry feedback" do
    visit new_session_path
    fill_in "Email address", with: users(:one).email_address
    fill_in "Password", with: "password"

    SessionsController.cache_store.stub(:increment, 11) do
      click_button "Sign in"
      assert_selector "[role='alert']", text: "Try again later."
      assert_current_path new_session_path
      assert_field "Password", with: ""
    end
  end

  test "invalid credentials show feedback, clear the password, and allow retry" do
    user = users(:one)

    visit new_session_path
    fill_in "Email address", with: user.email_address
    fill_in "Password", with: "wrong-password"
    click_button "Sign in"

    assert_current_path new_session_path
    assert_selector "[role='alert']", text: "Try another email address or password."
    assert_field "Email address", with: user.email_address
    assert_field "Password", with: ""

    fill_in "Password", with: "password"
    click_button "Sign in"

    assert_current_path root_path
    assert_text "Welcome back, #{user.email_address}."
  end

  test "inactive credentials receive the same generic sign-in feedback" do
    user = users(:one)
    user.update!(active: false)

    visit new_session_path
    fill_in "Email address", with: user.email_address
    fill_in "Password", with: "password"
    click_button "Sign in"

    assert_current_path new_session_path
    assert_selector "[role='alert']", text: "Try another email address or password."
    assert_field "Password", with: ""
  end

  test "admin can deactivate a user from the detail page without a remove action" do
    user = users(:one)
    user.update!(active: true)
    system_sign_in_as(users(:admin))

    visit admin_user_path(user)

    assert_button "Deactivate account"
    assert_no_button "Remove record"
    click_button "Deactivate account"
    within "[role='dialog']" do
      assert_text "This staff member will no longer be able to sign in."
      click_button "Deactivate account"
    end

    assert_current_path admin_users_path
    assert_text "User updated."
    assert_not user.reload.active?

    visit admin_user_path(user)
    assert_no_button "Deactivate account"
    assert_no_button "Remove record"
  end
end
