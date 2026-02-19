# frozen_string_literal: true

module Orders
  # Optimized version of CalculateTotals that handles both order-level and
  # line-level discounts. Line-level discounts are stored per-line with
  # granular exclusion capability.
  class CalculateTotals
    def self.call(order)
      new(order).call
    end

    def initialize(order)
      @order = order
    end

    def call
      # Load all data in minimal queries
      lines = load_order_lines
      order_discounts = load_order_discounts
      line_discounts = load_line_discounts(lines)

      recalculate_line_taxes(lines)
      apply_order_discounts(lines, order_discounts)
      apply_line_discounts(lines, line_discounts)
      update_order_totals(lines, order_discounts, line_discounts)

      @order.save!
      @order
    end

    private

      def load_order_lines
        @order.order_lines.includes(:tax_code).to_a
      end

      def load_order_discounts
        @order.order_discounts.to_a
      end

      def load_line_discounts(lines)
        line_ids = lines.map(&:id)
        OrderLineDiscount.where(order_line_id: line_ids).to_a.group_by(&:order_line_id)
      end

      def recalculate_line_taxes(lines)
        customer_tax_code = @order.customer&.tax_code
        return if customer_tax_code.nil? && lines.all? { |l| l.tax_code_id.present? }

        lines_to_update = []

        lines.each do |line|
          next if line.sellable_type == "GiftCertificate"

          effective_tax_code = customer_tax_code || line.tax_code
          new_rate = effective_tax_code&.rate || 0

          if line.tax_rate != new_rate
            line.tax_rate = new_rate
            line.tax_code = effective_tax_code if customer_tax_code
            lines_to_update << line if line.changed?
          end
        end

        # Bulk update to reduce SQL queries
        lines_to_update.each(&:save!) if lines_to_update.any?
      end

      def apply_order_discounts(lines, order_discounts)
        return if lines.empty?

        order_discounts.each do |discount|
          new_amount = calculate_order_discount_amount(discount, lines)

          if discount.calculated_amount != new_amount
            discount.calculated_amount = new_amount
            discount.save!
          end
        end
      end

      def calculate_order_discount_amount(discount, lines)
        # Gift certificates are never eligible for discounts
        eligible_lines = lines.reject { |line| line.sellable_type == "GiftCertificate" }
        subtotal = eligible_lines.sum(&:subtotal_before_discount)

        amount = if discount.percentage?
          subtotal * (discount.value / 100.0)
        elsif discount.fixed_per_item?
          discount.value * lines.sum(&:quantity)
        else
          [ discount.value, subtotal ].min
        end

        amount.round(2)
      end

      def apply_line_discounts(lines, line_discounts_by_line)
        return if lines.empty?

        line_discounts_to_update = []

        lines.each do |line|
          active_discounts = (line_discounts_by_line[line.id] || []).select(&:active?)

          if active_discounts.empty?
            # Reset discount_amount to 0 when no active discounts
            line.discount_amount = 0 if line.discount_amount != 0
            next
          end

          active_discounts.each do |line_discount|
            new_amount = calculate_line_discount_amount(line_discount, line)

            if line_discount.calculated_amount != new_amount
              line_discount.calculated_amount = new_amount
              line_discounts_to_update << line_discount
            end
          end

          # Update the line's total discount amount
          line.discount_amount = active_discounts.sum(&:calculated_amount)
        end

        # Bulk update line discounts
        line_discounts_to_update.each(&:save!) if line_discounts_to_update.any?

        # Bulk update order lines
        lines_to_update = lines.select { |l| l.changed? }
        lines_to_update.each(&:save!) if lines_to_update.any?
      end

      def calculate_line_discount_amount(line_discount, line)
        applied_qty = line_discount.applied_quantity
        total_qty = line.quantity

        return 0 if applied_qty <= 0 || total_qty <= 0

        amount = if line_discount.percentage?
          # Percentage applies to the discounted units' share of subtotal
          unit_subtotal = line.subtotal_before_discount / total_qty
          (unit_subtotal * applied_qty) * (line_discount.value / 100.0)
        elsif line_discount.fixed_per_item?
          line_discount.value * applied_qty
        else
          # Fixed amount - prorate based on discounted units
          full_amount = [ line_discount.value, line.subtotal_before_discount ].min
          (full_amount * applied_qty / total_qty).round(2)
        end

        amount.round(2)
      end

      def update_order_totals(lines, order_discounts, line_discounts_by_line)
        @order.subtotal = lines.sum(&:subtotal_before_discount).round(2)

        order_discount_total = order_discounts.sum(&:calculated_amount)
        line_discount_total = line_discounts_by_line.values.flatten.select(&:active?).sum(&:calculated_amount)

        @order.discount_total = (order_discount_total + line_discount_total).round(2)
        @order.tax_total = lines.sum(&:tax_amount).round(2)
        @order.total = (@order.subtotal - @order.discount_total + @order.tax_total).round(2)
      end
  end
end
