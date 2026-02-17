# frozen_string_literal: true

module Orders
  # Recomputes subtotal, discount_total, tax_total, and total from the order's
  # lines and discounts. When a customer with a tax_code is assigned, that tax
  # code overrides the product-level tax code for each line.
  #
  # Call this after every line, discount, or customer change.
  class CalculateTotals
    def self.call(order)
      new(order).call
    end

    def initialize(order)
      @order = order
    end

    def call
      recalculate_line_taxes
      apply_discounts
      update_order_totals
      @order.save!
      @order
    end

    private

      def recalculate_line_taxes
        customer_tax_code = @order.customer&.tax_code

        @order.order_lines.reload.each do |line|
          effective_tax_code = customer_tax_code || line.tax_code
          new_rate = effective_tax_code&.rate || 0

          if line.tax_rate != new_rate
            line.tax_rate = new_rate
            line.tax_code = effective_tax_code if customer_tax_code
          end

          line.save! if line.changed?
        end
      end

      def apply_discounts
        @order.order_discounts.reload.each do |discount|
          applicable_lines = if discount.applies_to_all_items?
            @order.order_lines
          else
            discount.order_lines
          end

          discount.calculated_amount = if discount.percentage?
            subtotal_of(applicable_lines) * (discount.value / 100.0)
          else
            [ discount.value, subtotal_of(applicable_lines) ].min
          end.round(2)

          discount.save! if discount.changed?
        end

        distribute_discounts_to_lines
      end

      def subtotal_of(lines)
        lines.sum { |l| l.subtotal_before_discount }
      end

      def distribute_discounts_to_lines
        total_discount = @order.order_discounts.sum(:calculated_amount)
        lines = @order.order_lines.reload

        return if lines.empty? || total_discount.zero?

        line_subtotals = lines.map(&:subtotal_before_discount)
        grand_subtotal = line_subtotals.sum

        return if grand_subtotal.zero?

        distributed = 0
        lines.each_with_index do |line, idx|
          if idx == lines.size - 1
            line.discount_amount = (total_discount - distributed).round(2)
          else
            share = (line.subtotal_before_discount / grand_subtotal * total_discount).round(2)
            line.discount_amount = share
            distributed += share
          end
          line.save! if line.changed?
        end
      end

      def update_order_totals
        lines = @order.order_lines.reload
        @order.subtotal = lines.sum(&:subtotal_before_discount).round(2)
        @order.discount_total = @order.order_discounts.sum(:calculated_amount).round(2)
        @order.tax_total = lines.sum(&:tax_amount).round(2)
        @order.total = (@order.subtotal - @order.discount_total + @order.tax_total).round(2)
      end
  end
end
