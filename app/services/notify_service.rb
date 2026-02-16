# frozen_string_literal: true

class NotifyService
  def self.call(user:, title:, body: nil, category: nil, url: nil, persistent: true)
    new(user:, title:, body:, category:, url:, persistent:).call
  end

  def initialize(user:, title:, body:, category:, url:, persistent:)
    @user = user
    @title = title
    @body = body
    @category = category
    @url = url
    @persistent = persistent
  end

  def call
    notification = persist_notification if @persistent
    broadcast_action_cable(notification)
    send_web_push
  end

  private

    def persist_notification
      @user.notifications.create!(
        title: @title,
        body: @body,
        category: @category,
        url: @url,
        persistent: true
      )
    end

    def broadcast_action_cable(notification)
      payload = {
        id: notification&.id,
        title: @title,
        body: @body,
        category: @category,
        url: @url,
        persistent: @persistent,
        created_at: notification&.created_at&.iso8601 || Time.current.iso8601
      }

      NotificationChannel.broadcast_to(@user, payload)
    end

    def send_web_push
      subscriptions = @user.push_subscriptions
      return if subscriptions.none?

      message = { title: @title, body: @body, url: @url }.to_json

      subscriptions.find_each do |sub|
        WebPush.payload_send(
          message: message,
          endpoint: sub.endpoint,
          p256dh: sub.p256dh_key,
          auth: sub.auth_key,
          vapid: vapid_keys
        )
      rescue WebPush::ExpiredSubscription, WebPush::InvalidSubscription
        sub.destroy
      rescue WebPush::ResponseError => e
        Rails.logger.warn { "[NotifyService] Web Push failed for subscription #{sub.id}: #{e.message}" }
      end
    end

    def vapid_keys
      {
        subject: ENV.fetch("VAPID_CONTACT", "mailto:admin@eipos.local"),
        public_key: ENV.fetch("VAPID_PUBLIC_KEY"),
        private_key: ENV.fetch("VAPID_PRIVATE_KEY")
      }
    end
end
