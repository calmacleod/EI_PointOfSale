# frozen_string_literal: true

require "test_helper"

class OrderTest < ActiveSupport::TestCase
  test "generates order number on create" do
    order = Order.create!(created_by: users(:admin))
    assert_match(/\AORD-\d{6}\z/, order.number)
  end

  test "number is unique" do
    order = orders(:draft_order)
    duplicate = Order.new(number: order.number, created_by: users(:admin))
    assert_not duplicate.valid?
    assert_includes duplicate.errors[:number], "has already been taken"
  end

  test "status defaults to draft" do
    order = Order.create!(created_by: users(:admin))
    assert order.draft?
  end

  test "amount_remaining returns remaining balance" do
    order = orders(:completed_order)
    assert_equal 0, order.amount_remaining
  end

  test "payment_complete? returns true when fully paid" do
    order = orders(:completed_order)
    assert order.payment_complete?
  end

  test "payment_complete? returns false when there is an outstanding balance" do
    order = orders(:held_order) # has total 16.94 but no payments
    assert_not order.payment_complete?
  end

  test "customer_name returns customer name or Quick Sale" do
    assert_equal "Acme Corp", orders(:completed_order).customer_name
    assert_equal "Quick Sale", orders(:draft_order).customer_name
  end

  test "prevents modification of completed orders" do
    order = orders(:completed_order)
    assert_raises(ActiveRecord::ReadOnlyRecord) do
      order.update!(notes: "trying to edit")
    end
  end

  test "allows status change on completed orders (for refunds)" do
    order = orders(:completed_order)
    order.update_column(:status, Order.statuses[:partially_refunded])
    order.reload
    assert order.partially_refunded?
  end

  test "finalized? returns true for completed/voided/refunded" do
    assert orders(:completed_order).finalized?
    assert_not orders(:draft_order).finalized?
  end
end
