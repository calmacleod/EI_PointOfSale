# frozen_string_literal: true

require "test_helper"

class Orders::HoldResumeTest < ActiveSupport::TestCase
  test "holds a draft order" do
    order = orders(:draft_order)
    admin = users(:admin)

    Orders::Hold.call(order: order, actor: admin)
    order.reload

    assert order.held?
    assert_not_nil order.held_at
    assert_equal "held", order.order_events.last.event_type
  end

  test "cannot hold a non-draft order" do
    order = orders(:completed_order)
    admin = users(:admin)

    assert_raises(ArgumentError) do
      Orders::Hold.call(order: order, actor: admin)
    end
  end

  test "resumes a held order" do
    order = orders(:held_order)
    admin = users(:admin)

    Orders::Resume.call(order: order, actor: admin)
    order.reload

    assert order.draft?
    assert_nil order.held_at
    assert_equal "resumed", order.order_events.last.event_type
  end

  test "cannot resume a non-held order" do
    order = orders(:draft_order)
    admin = users(:admin)

    assert_raises(ArgumentError) do
      Orders::Resume.call(order: order, actor: admin)
    end
  end
end
