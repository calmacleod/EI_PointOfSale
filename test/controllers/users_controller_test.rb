require "test_helper"

class UsersControllerTest < ActionDispatch::IntegrationTest
  test "index requires authentication" do
    get users_path
    assert_redirected_to new_session_path
  end

  test "signed in user can view show" do
    user = users(:one)
    sign_in_as(user)

    get user_path(user)

    assert_response :success
    assert_includes response.body, user.email_address
  end

  test "signed in user can view index and sees signed in users" do
    user1 = users(:one)
    user2 = users(:two)

    sign_in_as(user1)

    get users_path

    assert_response :success
    assert_includes response.body, user1.email_address
    assert_includes response.body, user2.email_address
  end

  test "index date filter filters by created_at" do
    user = users(:one)
    sign_in_as(user)

    get users_path(created_at_from: user.created_at.to_date.to_s)

    assert_response :success
    assert_includes response.body, user.email_address
  end

  test "index search filters users and preserves q in pagination" do
    user1 = users(:one)
    user2 = users(:two)

    sign_in_as(user1)

    get users_path(q: user1.email_address)

    assert_response :success
    assert_includes response.body, user1.email_address
    assert_not_includes response.body, user2.email_address
    assert_includes response.body, "users_table"
    assert_includes response.body, ERB::Util.html_escape(user1.email_address)
  end

  test "non-admin cannot edit or update users" do
    user = users(:one)
    other_user = users(:two)

    sign_in_as(user)

    get edit_user_path(other_user)
    assert_redirected_to root_path

    patch user_path(other_user), params: { user: { name: "Hacked" } }
    assert_redirected_to root_path
    assert_not_equal "Hacked", other_user.reload.name
  end

  test "common user can edit and update themselves (but cannot change role)" do
    user = users(:one)
    sign_in_as(user)

    get edit_user_path(user)
    assert_response :success

    patch user_path(user), params: { user: { name: "Self Updated", type: "Admin" } }
    assert_redirected_to users_path
    assert_equal "Self Updated", user.reload.name
    assert_equal "Common", user.reload.type
  end

  test "admin can update users" do
    admin = Admin.create!(
      email_address: "admin-update@example.com",
      password: "password",
      password_confirmation: "password"
    )
    user = users(:one)

    sign_in_as(admin)

    patch user_path(user), params: { user: { name: "Updated Name", type: "Admin" } }

    assert_redirected_to users_path
    updated_user = User.find(user.id)
    assert_equal "Updated Name", updated_user.name
    assert_equal "Admin", updated_user.type
  end
end
