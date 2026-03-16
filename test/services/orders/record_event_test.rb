# frozen_string_literal: true

require "test_helper"

class Orders::RecordEventTest < ActiveSupport::TestCase
  setup do
    @order = orders(:draft_order)
    @admin = users(:admin)
  end

  test "creates an OrderEvent with correct attributes" do
    assert_difference "OrderEvent.count", 1 do
      Orders::RecordEvent.call(
        order: @order,
        event_type: "created",
        actor: @admin
      )
    end

    event = @order.order_events.last
    assert_equal "created", event.event_type
    assert_equal @admin, event.actor
    assert_equal @order, event.order
  end

  test "stores data payload on the event" do
    Orders::RecordEvent.call(
      order: @order,
      event_type: "line_added",
      actor: @admin,
      data: { name: "Dragon Shield", quantity: 2 }
    )

    event = @order.order_events.last
    assert_equal "Dragon Shield", event.data["name"]
    assert_equal 2, event.data["quantity"]
  end

  test "defaults data to empty hash when not provided" do
    Orders::RecordEvent.call(
      order: @order,
      event_type: "created",
      actor: @admin
    )

    event = @order.order_events.last
    assert_equal({}, event.data)
  end

  test "raises on invalid event_type" do
    assert_raises(ActiveRecord::RecordInvalid) do
      Orders::RecordEvent.call(
        order: @order,
        event_type: "invalid_type",
        actor: @admin
      )
    end
  end

  test "sets created_at to current time" do
    freeze_time do
      Orders::RecordEvent.call(order: @order, event_type: "created", actor: @admin)
      assert_in_delta Time.current, @order.order_events.last.created_at, 1.second
    end
  end
end
