# frozen_string_literal: true

require "test_helper"

class NotifyServiceTest < ActiveSupport::TestCase
  setup do
    @user = users(:one)
  end

  test "creates persistent notification record" do
    assert_difference "@user.notifications.count", 1 do
      NotifyService.call(
        user: @user,
        title: "Report ready",
        body: "Your report is done.",
        category: "report",
        url: "/reports/1",
        persistent: true
      )
    end

    notification = @user.notifications.last
    assert_equal "Report ready", notification.title
    assert_equal "Your report is done.", notification.body
    assert_equal "report", notification.category
    assert_equal "/reports/1", notification.url
    assert notification.persistent?
  end

  test "does not create record for ephemeral notification" do
    assert_no_difference "@user.notifications.count" do
      NotifyService.call(
        user: @user,
        title: "Backup done",
        persistent: false
      )
    end
  end

  test "broadcasts via Action Cable" do
    payload = nil
    NotificationChannel.stub(:broadcast_to, ->(user, data) { payload = data if user == @user }) do
      NotifyService.call(user: @user, title: "Test broadcast", persistent: false)
    end

    assert_not_nil payload
    assert_equal "Test broadcast", payload[:title]
  end

  test "skips web push when VAPID keys are not configured" do
    PushSubscription.create!(
      user: @user,
      endpoint: "https://fcm.googleapis.com/fcm/send/test123",
      p256dh_key: "key",
      auth_key: "auth"
    )

    original_public_key = ENV["VAPID_PUBLIC_KEY"]
    original_private_key = ENV["VAPID_PRIVATE_KEY"]
    ENV.delete("VAPID_PUBLIC_KEY")
    ENV.delete("VAPID_PRIVATE_KEY")

    WebPush.stub(:payload_send, ->(*) { raise "should not send" }) do
      assert_nothing_raised do
        NotifyService.call(user: @user, title: "Test push", persistent: false)
      end
    end
  ensure
    ENV["VAPID_PUBLIC_KEY"] = original_public_key
    ENV["VAPID_PRIVATE_KEY"] = original_private_key
  end
end
