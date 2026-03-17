# frozen_string_literal: true

class AddCheckConstraintToUnreadNotificationsCount < ActiveRecord::Migration[8.1]
  def up
    execute <<~SQL
      ALTER TABLE users
      ADD CONSTRAINT check_unread_notifications_count_non_negative
      CHECK (unread_notifications_count >= 0)
    SQL
  end

  def down
    execute <<~SQL
      ALTER TABLE users
      DROP CONSTRAINT check_unread_notifications_count_non_negative
    SQL
  end
end
