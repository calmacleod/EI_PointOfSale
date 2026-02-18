# frozen_string_literal: true

module Orders
  # Optimized version of CalculateTotals that minimizes database queries
  # and performs bulk updates where possible.
  class CalculateTotals
    def self.call(order)
      new(order).call
    end

    def initialize(order)
      @order = order
    end

    def call
      # Load all data in a single query to avoid N+1
      lines = load_order_lines
      discounts = load_order_discounts

      recalculate_line_taxes(lines)
      apply_discounts(lines, discounts)
      update_order_totals(lines, discounts)

      @order.save!
      @order
    end

    private

      def load_order_lines
        @order.order_lines.includes(:tax_code).to_a
      end

      def load_order_discounts
        @order.order_discounts.includes(:order_discount_items, :order_lines).to_a
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

      def apply_discounts(lines, discounts)
        return if discounts.empty?

        discounts.each do |discount|
          applicable_lines = applicable_lines_for(discount, lines)
          next if applicable_lines.empty?

          new_amount = calculate_discount_amount(discount, applicable_lines)

          if discount.calculated_amount != new_amount
            discount.calculated_amount = new_amount
            discount.save!
          end
        end

        distribute_discounts_to_lines(lines, discounts)
      end

      def calculate_discount_amount(discount, lines)
        amount = if discount.percentage?
          subtotal_of(lines) * (discount.value / 100.0)
        elsif discount.fixed_per_item?
          discount.value * lines.sum(&:quantity)
        else
          [ discount.value, subtotal_of(lines) ].min
        end

        amount.round(2)
      end

      def subtotal_of(lines)
        lines.sum { |l| l.subtotal_before_discount }
      end

      def applicable_lines_for(discount, all_lines)
        if discount.applies_to_all_items?
          all_lines
        else
          # Get line IDs from discount items
          applicable_line_ids = discount.order_discount_items.map(&:order_line_id)
          all_lines.select { |l| applicable_line_ids.include?(l.id) }
        end
      end

      def distribute_discounts_to_lines(lines, discounts)
        return if lines.empty?

        line_discounts = Hash.new(0.0)

        discounts.each do |discount|
          applicable_lines = applicable_lines_for(discount, lines)
          next if applicable_lines.empty?

          if discount.fixed_per_item?
            applicable_lines.each do |line|
              line_discounts[line.id] += (discount.value * line.quantity).round(2)
            end
          else
            distribute_proportional_discount(discount, applicable_lines, line_discounts)
          end
        end

        # Bulk update lines to reduce SQL queries
        lines_to_update = []
        lines.each do |line|
          new_discount = line_discounts[line.id].round(2)
          if line.discount_amount != new_discount
            line.discount_amount = new_discount
            lines_to_update << line
          end
        end

        lines_to_update.each(&:save!) if lines_to_update.any?
      end

      def distribute_proportional_discount(discount, lines, line_discounts)
        subtotal = subtotal_of(lines)
        return if subtotal.zero?

        remaining = discount.calculated_amount

        lines.each_with_index do |line, idx|
          share = if idx == lines.size - 1
            remaining
          else
            s = (line.subtotal_before_discount / subtotal * discount.calculated_amount).round(2)
            remaining -= s
            s
          end
          line_discounts[line.id] += share
        end
      end

      def update_order_totals(lines, discounts)
        @order.subtotal = lines.sum(&:subtotal_before_discount).round(2)
        @order.discount_total = discounts.sum(&:calculated_amount).round(2)
        @order.tax_total = lines.sum(&:tax_amount).round(2)
        @order.total = (@order.subtotal - @order.discount_total + @order.tax_total).round(2)
      end
  end
end
