# frozen_string_literal: true

module Orders
  # Finalizes an order: validates payment, adjusts stock, and freezes the record.
  class Complete
    Result = Struct.new(:success?, :order, :errors, keyword_init: true)

    def self.call(order:, actor:)
      new(order: order, actor: actor).call
    end

    def initialize(order:, actor:)
      @order = order
      @actor = actor
      @errors = []
    end

    def call
      validate!
      return failure if @errors.any?

      @order.transaction do
        adjust_stock_levels
        finalize_order
        record_event
      end

      Result.new(success?: true, order: @order, errors: [])
    rescue => e
      Result.new(success?: false, order: @order, errors: [ e.message ])
    end

    private

      def validate!
        @errors << "Only draft orders can be completed" unless @order.draft?
        @errors << "Order has no items" if @order.order_lines.empty?
        @errors << "Payment is incomplete ($#{@order.amount_remaining} remaining)" unless @order.payment_complete?
      end

      def failure
        Result.new(success?: false, order: @order, errors: @errors)
      end

      def adjust_stock_levels
        @order.order_lines.includes(:sellable).find_each do |line|
          sellable = line.sellable
          next unless sellable.is_a?(Product)

          sellable.update_column(:stock_level, sellable.stock_level - line.quantity)
        end
      end

      def finalize_order
        @order.update!(
          status: :completed,
          completed_at: Time.current,
          cash_drawer_session: CashDrawerSession.current
        )
      end

      def record_event
        RecordEvent.call(
          order: @order,
          event_type: "completed",
          actor: @actor,
          data: {
            total: @order.total.to_s,
            items_count: @order.order_lines.sum(:quantity),
            payment_methods: @order.order_payments.map(&:display_method).uniq
          }
        )
      end
  end
end
