# frozen_string_literal: true

module Orders
  # Creates a Refund and RefundLines, optionally restocks items,
  # and updates the order status.
  class ProcessRefund
    Result = Struct.new(:success?, :refund, :errors, keyword_init: true)

    def self.call(order:, actor:, line_params:, reason: nil)
      new(order: order, actor: actor, line_params: line_params, reason: reason).call
    end

    def initialize(order:, actor:, line_params:, reason: nil)
      @order = order
      @actor = actor
      @line_params = line_params
      @reason = reason
      @errors = []
    end

    def call
      validate!
      return failure if @errors.any?

      refund = nil
      @order.transaction do
        refund = create_refund
        process_restock(refund)
        update_order_status(refund)
        record_event(refund)
      end

      Result.new(success?: true, refund: refund, errors: [])
    rescue => e
      Result.new(success?: false, refund: nil, errors: [ e.message ])
    end

    private

      def validate!
        unless @order.completed? || @order.partially_refunded?
          @errors << "Only completed orders can be refunded"
        end

        @errors << "No items selected for refund" if @line_params.blank?
      end

      def failure
        Result.new(success?: false, refund: nil, errors: @errors)
      end

      def create_refund
        refund_lines_attrs = @line_params.map do |lp|
          order_line = @order.order_lines.find(lp[:order_line_id])
          qty = lp[:quantity].to_i
          amount = (order_line.line_total / order_line.quantity * qty).round(2)

          { order_line: order_line, quantity: qty, amount: amount, restock: lp[:restock] == true }
        end

        total = refund_lines_attrs.sum { |a| a[:amount] }
        full = total >= @order.total

        refund = Refund.create!(
          order: @order,
          refund_type: full ? :full : :partial,
          reason: @reason,
          total: total,
          processed_by: @actor
        )

        refund_lines_attrs.each do |attrs|
          refund.refund_lines.create!(attrs)
        end

        refund
      end

      def process_restock(refund)
        refund.refund_lines.where(restock: true).includes(order_line: :sellable).find_each do |rl|
          sellable = rl.order_line.sellable
          next unless sellable.is_a?(Product)

          sellable.update_column(:stock_level, sellable.stock_level + rl.quantity)
        end
      end

      def update_order_status(refund)
        new_status = refund.full? ? :refunded : :partially_refunded
        @order.update_column(:status, Order.statuses[new_status])
      end

      def record_event(refund)
        RecordEvent.call(
          order: @order,
          event_type: "refund_processed",
          actor: @actor,
          data: {
            refund_number: refund.refund_number,
            refund_type: refund.refund_type,
            total: refund.total.to_s,
            reason: refund.reason,
            lines_count: refund.refund_lines.count,
            restocked: refund.refund_lines.where(restock: true).count
          }
        )
      end
  end
end
