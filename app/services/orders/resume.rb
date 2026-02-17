# frozen_string_literal: true

module Orders
  class Resume
    def self.call(order:, actor:)
      raise ArgumentError, "Only held orders can be resumed" unless order.held?

      order.transaction do
        order.update!(status: :draft, held_at: nil)
        RecordEvent.call(order: order, event_type: "resumed", actor: actor)
      end

      order
    end
  end
end
