# frozen_string_literal: true

require "test_helper"

module AdminArea
  class RecurringTasksControllerTest < ActionDispatch::IntegrationTest
    test "non-admin cannot access recurring tasks" do
      sign_in_as(users(:one))
      get admin_recurring_tasks_path
      assert_redirected_to root_path
    end

    test "admin can view recurring tasks index" do
      sign_in_as(users(:admin))
      get admin_recurring_tasks_path
      assert_response :success
      assert_includes response.body, "Recurring Tasks"
    end

    test "admin can trigger a recurring task" do
      sign_in_as(users(:admin))
      task = SolidQueue::RecurringTask.find_by(key: "refresh_sales_counts") ||
             SolidQueue::RecurringTask.create!(
               key: "refresh_sales_counts",
               class_name: "RefreshSalesCountsJob",
               schedule: "every 6 hours",
               queue_name: "low",
               static: true
             )

      assert_enqueued_with(job: RefreshSalesCountsJob) do
        post run_admin_recurring_task_path(task)
      end

      assert_redirected_to admin_recurring_tasks_path
      follow_redirect!
      assert_includes response.body, "has been enqueued"
    end

    test "non-admin cannot trigger a recurring task" do
      sign_in_as(users(:one))
      task = SolidQueue::RecurringTask.first || SolidQueue::RecurringTask.create!(
        key: "test_task", class_name: "RefreshSalesCountsJob", schedule: "every hour", static: true
      )
      post run_admin_recurring_task_path(task)
      assert_redirected_to root_path
    end
  end
end
