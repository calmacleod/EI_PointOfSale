class Current < ActiveSupport::CurrentAttributes
  attribute :session, :notification_count
  delegate :user, to: :session, allow_nil: true

  def notification_unread_count
    return 0 unless user

    self.notification_count ||= user.notifications.persistent.unread.count
  end
end
