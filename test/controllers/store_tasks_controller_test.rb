# frozen_string_literal: true

require "test_helper"

class StoreTasksControllerTest < ActionDispatch::IntegrationTest
  setup do
    sign_in_as(users(:admin))
  end

  # ── Index ──────────────────────────────────────────────────────────

  test "index lists store tasks" do
    get store_tasks_path
    assert_response :success
    assert_includes response.body, store_tasks(:clean_shelves).title
    assert_includes response.body, store_tasks(:restock_register).title
  end

  test "non-admin user can access store tasks" do
    sign_in_as(users(:one))
    get store_tasks_path
    assert_response :success
  end

  # ── Show ───────────────────────────────────────────────────────────

  test "show displays task details" do
    task = store_tasks(:clean_shelves)
    get store_task_path(task)
    assert_response :success
    assert_includes response.body, task.title
    assert_includes response.body, task.body
  end

  # ── New ────────────────────────────────────────────────────────────

  test "new renders form" do
    get new_store_task_path
    assert_response :success
    assert_includes response.body, "New Task"
  end

  # ── Create ─────────────────────────────────────────────────────────

  test "create adds a store task" do
    assert_difference("StoreTask.count", 1) do
      post store_tasks_path, params: {
        store_task: {
          title: "Mop the floor",
          body: "Back room needs mopping",
          status: "not_started",
          due_date: 3.days.from_now.to_date
        }
      }
    end

    assert_redirected_to store_tasks_path
    assert_equal "Mop the floor", StoreTask.order(:created_at).last.title
  end

  test "create with assigned user" do
    assert_difference("StoreTask.count", 1) do
      post store_tasks_path, params: {
        store_task: {
          title: "Assigned task",
          assigned_to_id: users(:one).id
        }
      }
    end

    task = StoreTask.order(:created_at).last
    assert_equal users(:one), task.assigned_to
  end

  test "create with invalid params renders new" do
    assert_no_difference("StoreTask.count") do
      post store_tasks_path, params: {
        store_task: { title: "" }
      }
    end

    assert_response :unprocessable_entity
  end

  # ── Edit ───────────────────────────────────────────────────────────

  test "edit renders form" do
    task = store_tasks(:clean_shelves)
    get edit_store_task_path(task)
    assert_response :success
    assert_includes response.body, task.title
  end

  # ── Update ─────────────────────────────────────────────────────────

  test "update modifies task" do
    task = store_tasks(:clean_shelves)
    patch store_task_path(task), params: {
      store_task: { title: "Updated Title", status: "in_progress" }
    }

    assert_redirected_to store_task_path(task)
    task.reload
    assert_equal "Updated Title", task.title
    assert task.in_progress?
  end

  test "update with invalid params renders edit" do
    task = store_tasks(:clean_shelves)
    patch store_task_path(task), params: {
      store_task: { title: "" }
    }

    assert_response :unprocessable_entity
  end

  # ── Destroy ────────────────────────────────────────────────────────

  test "destroy deletes task" do
    task = store_tasks(:clean_shelves)
    assert_difference("StoreTask.count", -1) do
      delete store_task_path(task)
    end

    assert_redirected_to store_tasks_path
  end

  # ── Authorization ──────────────────────────────────────────────────

  test "unauthenticated user is redirected" do
    sign_out
    get store_tasks_path
    assert_redirected_to new_session_path
  end
end
