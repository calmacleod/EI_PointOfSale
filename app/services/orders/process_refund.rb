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

      refund = @order.transaction do
        created_refund = create_refund
        process_restock(created_refund)
        update_order_status(created_refund)
        record_event(created_refund)
        created_refund
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
        validate_refund_quantities if @line_params.present?
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
        full = fully_refunded_after?(requested_quantities_by_line_id)

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

          stock_level = sellable.stock_level or raise "Product stock level is missing"
          sellable.update_column(:stock_level, stock_level + rl.quantity)
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

      def validate_refund_quantities
        requested_quantities_by_line_id.each do |order_line_id, requested_quantity|
          order_line = @order.order_lines.find_by(id: order_line_id)
          unless order_line
            @errors << "Refund line does not belong to this order"
            next
          end

          if requested_quantity <= 0
            @errors << "#{order_line.name} refund quantity must be greater than 0"
            next
          end

          remaining_quantity = remaining_refundable_quantity(order_line)
          if requested_quantity > remaining_quantity
            @errors << "#{order_line.name} refund quantity exceeds remaining refundable quantity (#{remaining_quantity})"
          end
        end
      end

      def requested_quantities_by_line_id
        cached_quantities = @requested_quantities_by_line_id
        return cached_quantities if cached_quantities

        # @type var quantities: Hash[Integer, Integer]
        quantities = {}
        @line_params.each do |line_param|
          order_line_id = line_param[:order_line_id].to_i
          # @type var quantity: Integer
          quantity = line_param[:quantity].to_i
          quantities[order_line_id] = quantities.fetch(order_line_id, 0) + quantity
        end
        @requested_quantities_by_line_id = quantities
      end

      def remaining_refundable_quantity(order_line)
        order_line.quantity - refunded_quantities_by_line_id.fetch(order_line.id, 0)
      end

      def refunded_quantities_by_line_id
        @refunded_quantities_by_line_id ||= RefundLine.joins(:refund)
          .where(refunds: { order_id: @order.id })
          .group(:order_line_id)
          .sum(:quantity)
      end

      def fully_refunded_after?(requested_quantities)
        @order.order_lines.all? do |order_line|
          remaining_refundable_quantity(order_line) - requested_quantities.fetch(order_line.id, 0) <= 0
        end
      end
  end
end
