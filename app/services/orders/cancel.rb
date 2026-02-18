# frozen_string_literal: true

module Orders
  class Cancel
    def self.call(order:, actor:)
      raise ArgumentError, "Only draft or held orders can be cancelled" unless order.draft? || order.held?

      order.transaction do
        order.order_lines.includes(:sellable).each do |line|
          next unless line.sellable.is_a?(GiftCertificate) && line.sellable.pending?

          line.sellable.update!(status: :voided, voided_at: Time.current)
        end

        order.update!(status: :cancelled)
        RecordEvent.call(order: order, event_type: "cancelled", actor: actor)
      end

      order
    end
  end
end
