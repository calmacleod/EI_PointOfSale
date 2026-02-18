# frozen_string_literal: true

module OrderLines
  # Adds a sellable to an order, optionally incrementing quantity if it already exists.
  # Handles discount auto-application, totals recalculation, and event recording.
  class Add
    Result = Struct.new(:success?, :line, :action, :error, keyword_init: true)

    def self.call(order:, sellable:, actor:, quantity: 1, increment_if_exists: false)
      new(order:, sellable:, actor:, quantity:, increment_if_exists:).call
    end

    def initialize(order:, sellable:, actor:, quantity:, increment_if_exists:)
      @order = order
      @sellable = sellable
      @actor = actor
      @quantity = quantity.to_i
      @increment_if_exists = increment_if_exists
    end

    def call
      return error_result("Sellable is required") unless @sellable
      return error_result("Order cannot be modified") if @order.finalized?

      line, action = find_or_create_line
      apply_discounts_and_totals
      record_event(line, action)

      Result.new(success?: true, line:, action:)
    end

    private

      def find_or_create_line
        existing_line = @order.order_lines.find_by(sellable: @sellable)

        if existing_line && @increment_if_exists
          existing_line.update!(quantity: existing_line.quantity + @quantity)
          [ existing_line, :incremented ]
        else
          line = create_new_line
          [ line, :created ]
        end
      end

      def create_new_line
        line = @order.order_lines.build(quantity: @quantity)
        line.snapshot_from_sellable!(@sellable, customer_tax_code: @order.customer&.tax_code)
        line.position = (@order.order_lines.maximum(:position) || 0) + 1
        line.save!
        line
      end

      def apply_discounts_and_totals
        Discounts::AutoApply.call(@order)
        Orders::CalculateTotals.call(@order)
      end

      def record_event(line, action)
        if action == :incremented
          Orders::RecordEvent.call(
            order: @order,
            event_type: "line_quantity_changed",
            actor: @actor,
            data: { name: line.name, new_quantity: line.quantity }
          )
        else
          Orders::RecordEvent.call(
            order: @order,
            event_type: "line_added",
            actor: @actor,
            data: { name: line.name, code: line.code, quantity: line.quantity, unit_price: line.unit_price.to_s }
          )
        end
      end

      def error_result(message)
        Result.new(success?: false, line: nil, action: nil, error: message)
      end
  end
end
