class Current < ActiveSupport::CurrentAttributes
  attribute :session, :store
  delegate :user, to: :session, allow_nil: true

  def notification_unread_count
    return 0 unless user

    user.unread_notifications_count
  end
end
