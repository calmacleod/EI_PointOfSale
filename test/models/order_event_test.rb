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
end
