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
      @order.with_lock do
        validate!
        if @errors.any?
          failure
        else
          refund = create_refund
          process_restock(refund)
          update_order_status(refund)
          record_event(refund)
          Result.new(success?: true, refund: refund, errors: [])
        end
      end
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
        refunded_quantities = refunded_quantities_by_line_id.dup
        discount_allocations = order_discount_allocations_by_line_id

        refund_lines_attrs = @line_params.map do |lp|
          order_line = @order.order_lines.find(lp[:order_line_id])
          # @type var qty: Integer
          qty = lp[:quantity].to_i
          previously_refunded_quantity = refunded_quantities.fetch(order_line.id, 0)
          cumulative_quantity = previously_refunded_quantity + qty
          amount = cumulative_refund_amount(order_line, cumulative_quantity, discount_allocations) -
            cumulative_refund_amount(order_line, previously_refunded_quantity, discount_allocations)
          refunded_quantities[order_line.id] = cumulative_quantity

          { order_line: order_line, quantity: qty, amount: amount, restock: lp[:restock] == true }
        end

        total = refund_lines_attrs.sum { |a| a[:amount] }
        remaining_order_total = @order.total.to_d - @order.refunds.sum(:total).to_d
        raise "Refund exceeds remaining refundable order total" if total > remaining_order_total

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

      def order_discount_allocations_by_line_id
        @order_discount_allocations_by_line_id ||= begin
          eligible_lines = @order.order_lines.to_a.reject { |line| line.sellable_type == "GiftCertificate" }
          total_discount = @order.order_discounts.sum(&:calculated_amount).to_d
          total_weight = eligible_lines.sum(&:subtotal_before_discount).to_d

          if eligible_lines.empty? || total_discount.zero? || total_weight.zero?
            {}
          else
            total_discount_cents = (total_discount * 100).round.to_i
            allocated_cents = 0
            fractional_allocations = []
            allocations_by_line_id = {}

            eligible_lines.each do |line|
              raw_cents = BigDecimal(total_discount_cents.to_s) * line.subtotal_before_discount.to_d / total_weight
              line_cents = raw_cents.floor
              allocations_by_line_id[line.id] = line_cents
              allocated_cents += line_cents
              fractional_allocations << [ line, raw_cents - line_cents ]
            end

            remaining_cents = total_discount_cents - allocated_cents
            fractional_allocations.sort_by { |line, fraction| [ -fraction, line.position, line.id ] }
              .take(remaining_cents)
              .each { |line, _fraction| allocations_by_line_id[line.id] += 1 }

            allocations_by_line_id.transform_values { |cents| cents.to_d / 100 }
          end
        end
      end

      def cumulative_refund_amount(order_line, cumulative_quantity, discount_allocations)
        line_amount = (order_line.line_total.to_d * cumulative_quantity / order_line.quantity).round(2)
        allocated_discount = discount_allocations.fetch(order_line.id, 0.to_d)
        discount_amount = (allocated_discount * cumulative_quantity / order_line.quantity).round(2)

        line_amount - discount_amount
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
