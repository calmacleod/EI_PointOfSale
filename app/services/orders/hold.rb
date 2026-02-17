# frozen_string_literal: true

module Orders
  class Hold
    def self.call(order:, actor:)
      raise ArgumentError, "Only draft orders can be held" unless order.draft?

      order.transaction do
        order.update!(status: :held, held_at: Time.current)
        RecordEvent.call(order: order, event_type: "held", actor: actor)
      end

      order
    end
  end
end
