# frozen_string_literal: true

require "test_helper"

class Orders::CancelTest < ActiveSupport::TestCase
  test "cancels a draft order" do
    order = orders(:draft_order)
    admin = users(:admin)

    Orders::Cancel.call(order: order, actor: admin)
    order.reload

    assert order.cancelled?
    assert_not order.discarded?
    assert_equal "cancelled", order.order_events.last.event_type
  end

  test "cancels a held order" do
    order = orders(:held_order)
    admin = users(:admin)

    Orders::Cancel.call(order: order, actor: admin)
    order.reload

    assert order.cancelled?
    assert_not order.discarded?
    assert_equal "cancelled", order.order_events.last.event_type
  end

  test "cannot cancel a completed order" do
    order = orders(:completed_order)
    admin = users(:admin)

    assert_raises(ArgumentError) do
      Orders::Cancel.call(order: order, actor: admin)
    end
  end
end
