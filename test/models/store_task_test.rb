# frozen_string_literal: true

require "test_helper"

class StoreTaskTest < ActiveSupport::TestCase
  # === Validations ===

  test "valid with title" do
    task = StoreTask.new(title: "Do the thing")
    assert task.valid?
  end

  test "invalid without title" do
    task = StoreTask.new(title: nil)
    assert_not task.valid?
    assert_includes task.errors[:title], "can't be blank"
  end

  test "invalid with title longer than 255 characters" do
    task = StoreTask.new(title: "x" * 256)
    assert_not task.valid?
  end

  test "valid without body" do
    task = StoreTask.new(title: "Just a title")
    assert task.valid?
  end

  test "valid without assigned_to" do
    task = StoreTask.new(title: "Unassigned task")
    assert task.valid?
  end

  # === Enums ===

  test "default status is not_started" do
    task = StoreTask.create!(title: "New task")
    assert task.not_started?
  end

  test "status enum values" do
    assert_equal({ "not_started" => 0, "in_progress" => 1, "blocked" => 2, "done" => 3 }, StoreTask.statuses)
  end

  # === Associations ===

  test "belongs to assigned_to user" do
    task = store_tasks(:clean_shelves)
    assert_equal users(:one), task.assigned_to
  end

  test "assigned_to is optional" do
    task = store_tasks(:inventory_count)
    assert_nil task.assigned_to
  end

  # === Scopes ===

  test "overdue scope returns non-done tasks past due date" do
    results = StoreTask.overdue
    assert_includes results, store_tasks(:overdue_task)
    assert_includes results, store_tasks(:fix_sign)
    assert_not_includes results, store_tasks(:inventory_count)
    assert_not_includes results, store_tasks(:clean_shelves)
  end

  test "upcoming scope returns non-done tasks with future due dates" do
    results = StoreTask.upcoming
    assert_includes results, store_tasks(:clean_shelves)
    assert_includes results, store_tasks(:restock_register)
    assert_not_includes results, store_tasks(:overdue_task)
  end

  test "assigned_to_user scope" do
    results = StoreTask.assigned_to_user(users(:one))
    assert_includes results, store_tasks(:clean_shelves)
    assert_includes results, store_tasks(:fix_sign)
    assert_not_includes results, store_tasks(:restock_register)
  end

  # === Instance Methods ===

  test "overdue? returns true for past-due non-done task" do
    task = store_tasks(:overdue_task)
    assert task.overdue?
  end

  test "overdue? returns false for done task even if past due" do
    task = store_tasks(:inventory_count)
    assert_not task.overdue?
  end

  test "overdue? returns false when no due date" do
    task = StoreTask.new(title: "No date", status: :not_started)
    assert_not task.overdue?
  end

  test "overdue? returns false for future due date" do
    task = store_tasks(:clean_shelves)
    assert_not task.overdue?
  end

  test "status_label returns humanized status" do
    assert_equal "Not Started", StoreTask.new(status: :not_started).status_label
    assert_equal "In Progress", StoreTask.new(status: :in_progress).status_label
    assert_equal "Blocked", StoreTask.new(status: :blocked).status_label
    assert_equal "Done", StoreTask.new(status: :done).status_label
  end
end
