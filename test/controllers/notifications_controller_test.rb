# frozen_string_literal: true

require "test_helper"

class NotificationsControllerTest < ActionDispatch::IntegrationTest
  setup do
    @user = users(:one)
    sign_in_as(@user)
  end

  test "index returns recent persistent notifications" do
    Notification.create!(user: @user, title: "Persistent one", persistent: true)
    Notification.create!(user: @user, title: "Ephemeral one", persistent: false)

    get notifications_path
    assert_response :success
    assert_includes response.body, "Persistent one"
  end

  test "mark_read marks a notification as read" do
    notification = Notification.create!(user: @user, title: "Unread")
    assert_nil notification.read_at

    patch mark_read_notification_path(notification), as: :json
    assert_response :success
    assert_not_nil notification.reload.read_at
    assert_equal 0, response.parsed_body["unread_count"]
  end

  test "mark_all_read marks all unread notifications" do
    n1 = Notification.create!(user: @user, title: "A", persistent: true)
    n2 = Notification.create!(user: @user, title: "B", persistent: true)

    patch mark_all_read_notifications_path, as: :json
    assert_response :success
    assert_not_nil n1.reload.read_at
    assert_not_nil n2.reload.read_at
    assert_equal 0, response.parsed_body["unread_count"]
  end

  test "requires authentication" do
    sign_out
    get notifications_path
    assert_redirected_to new_session_path
  end

  private

    def sign_out
      delete session_path
    end
end
