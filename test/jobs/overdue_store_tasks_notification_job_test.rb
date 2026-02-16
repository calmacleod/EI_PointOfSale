# frozen_string_literal: true

require "test_helper"

class OverdueStoreTasksNotificationJobTest < ActiveJob::TestCase
  test "creates notifications for assigned users with overdue tasks" do
    user = users(:one)
    overdue_count = StoreTask.overdue.where(assigned_to: user).count

    assert_difference -> { user.notifications.count }, overdue_count do
      OverdueStoreTasksNotificationJob.perform_now
    end

    notification = user.notifications.order(:created_at).last
    assert notification.title.start_with?("Overdue task:")
    assert notification.persistent?
  end

  test "does not notify for unassigned overdue tasks" do
    StoreTask.overdue.update_all(assigned_to_id: nil)

    assert_no_difference "Notification.count" do
      OverdueStoreTasksNotificationJob.perform_now
    end
  end

  test "does not notify for done tasks even if past due" do
    store_tasks(:overdue_task).update!(status: :done)

    assigned_overdue = StoreTask.overdue.where.not(assigned_to_id: nil)
    initial_count = Notification.count

    OverdueStoreTasksNotificationJob.perform_now

    remaining_notifications = Notification.count - initial_count
    assigned_overdue_count = assigned_overdue.count

    assert remaining_notifications <= assigned_overdue_count
  end

  test "does not duplicate notification if already sent today" do
    task = store_tasks(:overdue_task)
    user = task.assigned_to

    OverdueStoreTasksNotificationJob.perform_now
    count_after_first = user.notifications.count

    OverdueStoreTasksNotificationJob.perform_now
    assert_equal count_after_first, user.notifications.reload.count
  end
end
