# frozen_string_literal: true

class AddUnreadNotificationsCountToUsers < ActiveRecord::Migration[8.1]
  def up
    add_column :users, :unread_notifications_count, :integer, null: false, default: 0

    # Populate from existing data
    execute <<~SQL
      UPDATE users
      SET unread_notifications_count = (
        SELECT COUNT(*)
        FROM notifications
        WHERE notifications.user_id = users.id
          AND notifications.persistent = true
          AND notifications.read_at IS NULL
      )
    SQL
  end

  def down
    remove_column :users, :unread_notifications_count
  end
end
