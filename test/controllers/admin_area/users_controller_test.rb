# frozen_string_literal: true

require "test_helper"

module AdminArea
  class UsersControllerTest < ActionDispatch::IntegrationTest
    test "index requires authentication" do
      get admin_users_path
      assert_redirected_to new_session_path
    end

    test "non-admin cannot access users" do
      user = users(:one)
      sign_in_as(user)

      get admin_users_path
      assert_redirected_to root_path

      get admin_user_path(user)
      assert_redirected_to root_path

      get edit_admin_user_path(user)
      assert_redirected_to root_path

      patch admin_user_path(user), params: { user: { name: "Hacked" } }
      assert_redirected_to root_path
      assert_not_equal "Hacked", user.reload.name
    end

    test "admin can view index and sees users" do
      admin = users(:admin)
      user1 = users(:one)
      user2 = users(:two)

      sign_in_as(admin)

      get admin_users_path

      assert_response :success
      assert_includes response.body, user1.email_address
      assert_includes response.body, user2.email_address
    end

    test "admin can view user show" do
      admin = users(:admin)
      user = users(:one)

      sign_in_as(admin)

      get admin_user_path(user)

      assert_response :success
      assert_includes response.body, user.email_address
    end

    test "index date filter filters by created_at" do
      admin = users(:admin)
      user = users(:one)

      sign_in_as(admin)

      get admin_users_path(created_at_from: user.created_at.to_date.to_s)

      assert_response :success
      assert_includes response.body, user.email_address
    end

    test "index search filters users and preserves q in pagination" do
      admin = users(:admin)
      user1 = users(:one)
      user2 = users(:two)

      sign_in_as(admin)

      get admin_users_path(q: "Alice Johnson")

      assert_response :success
      assert_includes response.body, user1.email_address
      assert_not_includes response.body, user2.email_address
      assert_includes response.body, "users_table"
    end

    test "admin can update users" do
      admin = users(:admin)
      user = users(:one)

      sign_in_as(admin)

      patch admin_user_path(user), params: { user: { name: "Updated Name", type: "Admin" } }

      assert_redirected_to admin_users_path
      updated_user = User.find(user.id)
      assert_equal "Updated Name", updated_user.name
      assert_equal "Admin", updated_user.type
    end
  end
end
