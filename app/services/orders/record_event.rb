# frozen_string_literal: true

module Orders
  # Appends an immutable event to the order's audit trail.
  class RecordEvent
    def self.call(order:, event_type:, actor:, data: {})
      OrderEvent.create!(
        order: order,
        event_type: event_type,
        actor: actor,
        data: data,
        created_at: Time.current
      )
    end
  end
end
