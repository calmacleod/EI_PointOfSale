# frozen_string_literal: true

module Discounts
  # Optimized auto-apply that minimizes database queries and handles both
  # order-level and line-level discounts. Line-level discounts can be
  # excluded on a per-line basis using OrderLineDiscount.excluded_at.
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
      return if Discount.currently_active.none?

      # Load current state in minimal queries
      current_lines = load_order_lines
      existing_order_discounts = load_existing_order_discounts
      existing_line_discounts = load_existing_line_discounts

      # Sync order-level discounts (applies_to_all)
      sync_order_level_discounts(existing_order_discounts)

      # Sync line-level discounts (specific items)
      sync_line_level_discounts(current_lines, existing_line_discounts)
    end

    private

      def load_order_lines
        @order.order_lines.to_a
      end

      def load_existing_order_discounts
        @order.order_discounts.where.not(discount_id: nil).to_a
      end

      def load_existing_line_discounts
        @order.order_line_discounts.where(auto_applied: true).to_a
      end

      def sync_order_level_discounts(existing_discounts)
        applicable = find_applicable_order_level_discounts

        # Determine changes needed
        to_remove = existing_discounts.reject { |od| applicable.key?(od.discount_id) }
        to_add = applicable.reject { |id, _| existing_discounts.any? { |od| od.discount_id == id } }

        # Remove outdated order discounts
        to_remove.each(&:destroy)

        # Add new order discounts
        to_add.each do |discount_id, discount|
          create_order_level_discount(discount)
        end
      end

      def sync_line_level_discounts(lines, existing_line_discounts)
        return if lines.empty?

        # Group existing line discounts by source_discount_id for quick lookup
        existing_by_discount = existing_line_discounts.group_by(&:source_discount_id)

        # Get applicable discounts for lines
        applicable_discounts = find_applicable_line_level_discounts(lines)

        applicable_discounts.each do |discount, matching_lines|
          existing_for_discount = existing_by_discount[discount.id] || []

          matching_lines.each do |line|
            # Skip lines that have been destroyed since loading
            next unless line.persisted?

            existing = existing_for_discount.find { |ld| ld.order_line_id == line.id }

            if existing
              # Restore if it was excluded (user changed their mind)
              restore_if_excluded(existing)
            else
              # Create new line discount
              create_line_level_discount(discount, line)
            end
          end

          # Mark line discounts as removed if the line no longer qualifies
          # (e.g., line deleted or discount rules changed)
          line_ids = matching_lines.map(&:id)
          existing_for_discount.each do |existing|
            unless line_ids.include?(existing.order_line_id) || existing.excluded?
              existing.destroy!
            end
          end
        end

        # Clean up line discounts for discounts that no longer apply to any lines
        applicable_discount_ids = applicable_discounts.keys.map(&:id)
        existing_line_discounts.each do |line_discount|
          next if applicable_discount_ids.include?(line_discount.source_discount_id)

          line_discount.destroy!
        end
      end

      def find_applicable_order_level_discounts
        {}.tap do |applicable|
          Discount.currently_active.where(applies_to_all: true).find_each do |discount|
            applicable[discount.id] = discount
          end
        end
      end

      def find_applicable_line_level_discounts(lines)
        {}.tap do |applicable|
          Discount.currently_active.where(applies_to_all: false).includes(:discount_items).find_each do |discount|
            matching_lines = find_matching_lines(discount, discount.discount_items.to_a, lines)
            applicable[discount] = matching_lines unless matching_lines.empty?
          end
        end
      end

      def find_matching_lines(discount, discount_items, lines)
        return [] if discount_items.empty?

        # Build O(1) lookup set from discount items
        applicable_set = discount_items.each_with_object(Set.new) do |item, set|
          set.add([ item.discountable_type, item.discountable_id ])
        end

        # O(n) matching instead of O(n*m)
        lines.select { |line| applicable_set.include?([ line.sellable_type, line.sellable_id ]) }
      end

      def create_order_level_discount(discount)
        @order.order_discounts.create!(
          name: discount.name,
          discount_type: ORDER_DISCOUNT_TYPE_MAP[discount.discount_type],
          value: discount.value,
          scope: :all_items,
          discount_id: discount.id,
          applied_by: nil
        )
      end

      def create_line_level_discount(discount, line)
        line.order_line_discounts.create!(
          source_discount: discount,
          name: discount.name,
          discount_type: ORDER_DISCOUNT_TYPE_MAP[discount.discount_type],
          value: discount.value,
          calculated_amount: 0, # Will be calculated by CalculateTotals
          auto_applied: true
        )
      end

      def restore_if_excluded(line_discount)
        nil unless line_discount.fully_excluded?

        # Don't auto-restore discounts that were excluded (user explicitly removed them)
        # This method is intentionally empty - excluded discounts stay excluded
        # They can only be restored via OrderLineDiscountsController#restore
      end
  end
end
