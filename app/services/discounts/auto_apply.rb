# frozen_string_literal: true

module Discounts
  # Optimized auto-apply that minimizes database queries and only applies
  # discounts when necessary (not on every line item operation).
  class AutoApply
    ORDER_DISCOUNT_TYPE_MAP = {
      "percentage"    => "percentage",
      "fixed_total"   => "fixed_amount",
      "fixed_per_item" => "fixed_per_item"
    }.freeze

    def self.call(order)
      new(order).call
    end

    def initialize(order)
      @order = order
    end

    def call
      return if @order.finalized?

      overridden_ids = @order.metadata["overridden_discount_ids"] || []

      # Load current state in minimal queries
      current_lines = @order.order_lines.to_a
      existing_discounts = @order.order_discounts.where.not(discount_id: nil).to_a

      # Find which discounts should be applied based on current lines
      applicable_discounts = find_applicable_discounts(current_lines, overridden_ids)

      # Determine what needs to change
      discounts_to_remove = existing_discounts.reject { |od| applicable_discounts.key?(od.discount_id) }
      discounts_to_add = applicable_discounts.reject { |id, _| existing_discounts.any? { |od| od.discount_id == id } }

      # Only modify if necessary
      return if discounts_to_remove.empty? && discounts_to_add.empty?

      # Remove outdated discounts
      discounts_to_remove.each(&:destroy)

      # Add new discounts
      discounts_to_add.each do |discount_id, (discount, matching_lines)|
        create_order_discount(discount, matching_lines)
      end
    end

    private

      def find_applicable_discounts(lines, overridden_ids)
        return {} if lines.empty?

        applicable = {}

        # Only query active discounts if we have lines
        Discount.currently_active.where.not(id: overridden_ids).find_each do |discount|
          matching_lines = find_matching_lines(discount, lines)
          next if matching_lines.empty?

          applicable[discount.id] = [ discount, matching_lines ]
        end

        applicable
      end

      def find_matching_lines(discount, lines)
        return lines if discount.applies_to_all?

        # Build lookup map for O(1) matching
        discount_items = discount.discount_items.to_a

        lines.select do |line|
          discount_items.any? { |di| di.discountable_type == line.sellable_type && di.discountable_id == line.sellable_id }
        end
      end

      def create_order_discount(discount, matching_lines)
        od_scope = discount.applies_to_all? ? :all_items : :specific_items

        od = @order.order_discounts.create!(
          name: discount.name,
          discount_type: ORDER_DISCOUNT_TYPE_MAP[discount.discount_type],
          value: discount.value,
          scope: od_scope,
          discount_id: discount.id,
          applied_by: nil
        )

        # Only create items for specific discounts
        # Filter out destroyed lines (they may have been passed as stale objects)
        unless discount.applies_to_all?
          # Reload to get fresh IDs from database (in case lines were destroyed)
          existing_line_ids = @order.order_lines.reload.pluck(:id)
          valid_lines = matching_lines.select { |l| existing_line_ids.include?(l.id) }

          valid_lines.each do |line|
            od.order_discount_items.create!(order_line: line)
          end
        end

        od
      end
  end
end
