# frozen_string_literal: true

# Dev console helpers — load with: require Rails.root.join("lib/dev")
#
# Usage:
#   Dev::Notifications.send("alice@example.com", "Hello!", body: "Some details")
#   Dev::Notifications.send_all("System maintenance tonight")
#   Dev::Notifications.clear("alice@example.com")
#   Dev::Notifications.clear_all
#   Dev::Notifications.list("alice@example.com")

module Dev
  module Notifications
    # Send a persistent notification to a user by email.
    #
    #   Dev::Notifications.send("alice@example.com", "Your title", body: "Optional body")
    def self.send(email, title, body: nil)
      user = User.find_by!(email_address: email)
      n = user.notifications.create!(title: title, body: body, persistent: true)
      puts "Sent notification ##{n.id} to #{user.email_address} (unread count: #{user.reload.unread_notifications_count})"
      n
    end

    # Send a persistent notification to every user.
    #
    #   Dev::Notifications.send_all("System maintenance tonight")
    def self.send_all(title, body: nil)
      User.find_each do |user|
        n = user.notifications.create!(title: title, body: body, persistent: true)
        puts "  → #{user.email_address} (##{n.id})"
      end
      puts "Done."
    end

    # Destroy all unread persistent notifications for a user.
    #
    #   Dev::Notifications.clear("alice@example.com")
    def self.clear(email)
      user = User.find_by!(email_address: email)
      count = user.notifications.persistent.unread.destroy_all.size
      puts "Cleared #{count} unread persistent notification(s) for #{user.email_address}"
    end

    # Destroy all unread persistent notifications for every user.
    def self.clear_all
      count = Notification.persistent.unread.destroy_all.size
      puts "Cleared #{count} unread persistent notification(s) across all users."
    end

    # List recent notifications for a user.
    #
    #   Dev::Notifications.list("alice@example.com")
    def self.list(email)
      user = User.find_by!(email_address: email)
      notifications = user.notifications.recent
      if notifications.empty?
        puts "No notifications for #{user.email_address}"
      else
        notifications.each do |n|
          status = n.read? ? "read   " : "UNREAD "
          puts "  [#{status}] ##{n.id} #{n.created_at.strftime('%Y-%m-%d %H:%M')} | #{n.title}"
        end
      end
    end
  end
end
