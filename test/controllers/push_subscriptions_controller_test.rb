# frozen_string_literal: true

require "test_helper"

class PushSubscriptionsControllerTest < ActionDispatch::IntegrationTest
  setup do
    @user = users(:one)
    sign_in_as(@user)
  end

  test "create stores a new push subscription" do
    assert_difference "@user.push_subscriptions.count", 1 do
      post push_subscriptions_path, params: {
        push_subscription: {
          endpoint: "https://fcm.googleapis.com/fcm/send/test123",
          p256dh_key: "BNcRdreALRFXTkOOUHK1EtK2wtaz5Ry4YfYCA_0QTpQ",
          auth_key: "tBHItJI5svbpC7htQH8e2A"
        }
      }, as: :json
    end

    assert_response :created
  end

  test "create updates existing subscription with same endpoint" do
    PushSubscription.create!(
      user: @user,
      endpoint: "https://fcm.googleapis.com/fcm/send/test123",
      p256dh_key: "old_key",
      auth_key: "old_auth"
    )

    assert_no_difference "@user.push_subscriptions.count" do
      post push_subscriptions_path, params: {
        push_subscription: {
          endpoint: "https://fcm.googleapis.com/fcm/send/test123",
          p256dh_key: "new_key",
          auth_key: "new_auth"
        }
      }, as: :json
    end

    assert_response :created
    sub = @user.push_subscriptions.first
    assert_equal "new_key", sub.p256dh_key
    assert_equal "new_auth", sub.auth_key
  end

  test "destroy removes a push subscription" do
    PushSubscription.create!(
      user: @user,
      endpoint: "https://fcm.googleapis.com/fcm/send/test123",
      p256dh_key: "key",
      auth_key: "auth"
    )

    assert_difference "@user.push_subscriptions.count", -1 do
      delete push_subscription_path("unsubscribe"), params: {
        endpoint: "https://fcm.googleapis.com/fcm/send/test123"
      }, as: :json
    end

    assert_response :success
  end

  test "requires authentication" do
    sign_out
    post push_subscriptions_path, params: {
      push_subscription: {
        endpoint: "https://test.example.com",
        p256dh_key: "key",
        auth_key: "auth"
      }
    }, as: :json

    assert_response :redirect
  end

  private

    def sign_out
      delete session_path
    end
end
