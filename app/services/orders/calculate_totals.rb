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
          applicable_lines = applicable_lines_for(discount)

          discount.calculated_amount = if discount.percentage?
            subtotal_of(applicable_lines) * (discount.value / 100.0)
          elsif discount.fixed_per_item?
            discount.value * applicable_lines.sum(&:quantity)
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

      def applicable_lines_for(discount)
        if discount.applies_to_all_items?
          @order.order_lines
        else
          discount.order_lines
        end
      end

      def distribute_discounts_to_lines
        lines = @order.order_lines.reload
        return if lines.empty?

        line_discounts = lines.each_with_object({}) { |l, h| h[l.id] = 0.0 }

        @order.order_discounts.reload.each do |discount|
          applicable_lines = applicable_lines_for(discount)
          next if applicable_lines.empty?

          if discount.fixed_per_item?
            applicable_lines.each do |line|
              line_discounts[line.id] += (discount.value * line.quantity).round(2)
            end
          else
            subtotal = subtotal_of(applicable_lines)
            next if subtotal.zero?

            remaining = discount.calculated_amount
            applicable_lines.each_with_index do |line, idx|
              share = if idx == applicable_lines.size - 1
                remaining
              else
                s = (line.subtotal_before_discount / subtotal * discount.calculated_amount).round(2)
                remaining -= s
                s
              end
              line_discounts[line.id] += share
            end
          end
        end

        lines.each do |line|
          line.discount_amount = line_discounts[line.id].round(2)
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
