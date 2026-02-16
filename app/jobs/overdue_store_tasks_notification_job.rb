# frozen_string_literal: true

class OverdueStoreTasksNotificationJob < ApplicationJob
  queue_as :default

  def perform
    StoreTask.overdue.where.not(assigned_to_id: nil).includes(:assigned_to).find_each do |task|
      next if already_notified_today?(task)

      task.assigned_to.notifications.create!(
        title: "Overdue task: #{task.title}",
        body: "\"#{task.title}\" was due on #{I18n.l(task.due_date, format: :short)}.",
        persistent: true
      )
    end
  end

  private

    def already_notified_today?(task)
      task.assigned_to.notifications
          .where("created_at >= ?", Date.current.beginning_of_day)
          .where(title: "Overdue task: #{task.title}")
          .exists?
    end
end
