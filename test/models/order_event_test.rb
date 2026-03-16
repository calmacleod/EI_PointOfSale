# frozen_string_literal: true

require "test_helper"

class OrderEventTest < ActiveSupport::TestCase
  test "prevents update of persisted events" do
    event = order_events(:draft_created)
    assert_raises(ActiveRecord::ReadOnlyRecord) do
      event.update!(data: { "hacked" => true })
    end
  end

  test "prevents destroy of persisted events" do
    event = order_events(:draft_created)
    assert_raises(ActiveRecord::ReadOnlyRecord) do
      event.destroy!
    end
  end

  test "validates event_type inclusion" do
    event = OrderEvent.new(
      order: orders(:draft_order),
      actor: users(:admin),
      event_type: "invalid_type",
      created_at: Time.current
    )
    assert_not event.valid?
    assert_includes event.errors[:event_type], "is not included in the list"
  end

  test "description returns human-readable text" do
    event = order_events(:draft_created)
    assert_equal "Order created", event.description
  end

  test "accepts all known event_types" do
    OrderEvent::EVENT_TYPES.each do |type|
      event = OrderEvent.new(
        order: orders(:draft_order),
        actor: users(:admin),
        event_type: type,
        data: {}
      )
      assert event.valid?, "Expected event_type '#{type}' to be valid"
    end
  end

  test "description includes item name for line_added event" do
    event = OrderEvent.new(
      event_type: "line_added",
      data: { "name" => "Dragon Shield", "quantity" => 2 }
    )
    assert_match "Dragon Shield", event.description
    assert_match "2", event.description
  end

  test "description includes customer name for customer_assigned event" do
    event = OrderEvent.new(
      event_type: "customer_assigned",
      data: { "customer_name" => "Acme Corp" }
    )
    assert_match "Acme Corp", event.description
  end

  test "description includes refund total for refund_processed event" do
    event = OrderEvent.new(
      event_type: "refund_processed",
      data: { "total" => "15.00" }
    )
    assert_match "15.00", event.description
  end

  test "chronological scope orders by created_at ascending" do
    scope = OrderEvent.chronological
    direction = scope.order_values.first.direction.to_s
    assert_equal "asc", direction
  end

  test "recent scope orders by created_at descending" do
    scope = OrderEvent.recent
    direction = scope.order_values.first.direction.to_s
    assert_equal "desc", direction
  end
end
