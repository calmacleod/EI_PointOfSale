# frozen_string_literal: true

require "test_helper"

class NotificationTest < ActiveSupport::TestCase
  setup do
    @user = users(:one)
  end

  test "requires title" do
    notification = Notification.new(user: @user, title: nil)
    assert_not notification.valid?
    assert_includes notification.errors[:title], "can't be blank"
  end

  test "requires user" do
    notification = Notification.new(title: "Test", user: nil)
    assert_not notification.valid?
  end

  test "defaults persistent to true" do
    notification = Notification.create!(user: @user, title: "Test")
    assert notification.persistent?
  end

  test "unread scope returns notifications without read_at" do
    read = Notification.create!(user: @user, title: "Read", read_at: Time.current)
    unread = Notification.create!(user: @user, title: "Unread")

    results = @user.notifications.unread
    assert_includes results, unread
    assert_not_includes results, read
  end

  test "persistent scope excludes ephemeral notifications" do
    persistent = Notification.create!(user: @user, title: "Persistent", persistent: true)
    ephemeral = Notification.create!(user: @user, title: "Ephemeral", persistent: false)

    results = @user.notifications.persistent
    assert_includes results, persistent
    assert_not_includes results, ephemeral
  end

  test "mark_as_read! sets read_at" do
    notification = Notification.create!(user: @user, title: "Test")
    assert_nil notification.read_at

    notification.mark_as_read!
    assert_not_nil notification.reload.read_at
  end

  test "mark_as_read! is idempotent" do
    notification = Notification.create!(user: @user, title: "Test")
    notification.mark_as_read!
    original_read_at = notification.reload.read_at

    notification.mark_as_read!
    assert_equal original_read_at, notification.reload.read_at
  end

  test "recent scope orders by created_at desc and limits to 20" do
    25.times { |i| Notification.create!(user: @user, title: "N#{i}") }
    assert_equal 20, @user.notifications.recent.count
    assert_equal "N24", @user.notifications.recent.first.title
  end
end
