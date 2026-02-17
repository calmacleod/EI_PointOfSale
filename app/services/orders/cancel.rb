# frozen_string_literal: true

module Orders
  class Cancel
    def self.call(order:, actor:)
      raise ArgumentError, "Only draft or held orders can be cancelled" unless order.draft? || order.held?

      order.transaction do
        order.update!(status: :cancelled)
        RecordEvent.call(order: order, event_type: "cancelled", actor: actor)
      end

      order
    end
  end
end
