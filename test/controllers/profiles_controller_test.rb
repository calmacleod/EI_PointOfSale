require "test_helper"

class ProfilesControllerTest < ActionDispatch::IntegrationTest
  test "edit requires authentication" do
    get edit_profile_path
    assert_redirected_to new_session_path
  end

  test "common user can update their profile but cannot change role or active" do
    user = users(:one)
    sign_in_as(user)

    patch profile_path, params: { user: { name: "Me", type: "Admin", active: false } }
    assert_redirected_to edit_profile_path

    user.reload
    assert_equal "Me", user.name
    assert_equal "Common", user.type
    assert_equal true, user.active
  end
end


