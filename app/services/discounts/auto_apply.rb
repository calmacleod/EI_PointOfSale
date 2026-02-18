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
      return if Discount.currently_active.none?

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

        # Bulk load discount items for all discounts in a single query
        discount_data = load_discounts_with_items(overridden_ids)

        discount_data.each do |discount, items|
          matching_lines = find_matching_lines(discount, items, lines)
          next if matching_lines.empty?

          applicable[discount.id] = [ discount, matching_lines ]
        end

        applicable
      end

      def load_discounts_with_items(overridden_ids)
        # Eager load discount items for all active discounts in one query
        discounts = Discount.currently_active
                            .where.not(id: overridden_ids)
                            .includes(:discount_items)
                            .to_a

        # Build [discount, items] pairs
        discounts.map { |d| [ d, d.discount_items.to_a ] }
      end

      def find_matching_lines(discount, discount_items, lines)
        return lines if discount.applies_to_all?
        return [] if discount_items.empty?

        # Build O(1) lookup set from discount items
        applicable_set = discount_items.each_with_object(Set.new) do |item, set|
          set.add([ item.discountable_type, item.discountable_id ])
        end

        # O(n) matching instead of O(n*m)
        lines.select { |line| applicable_set.include?([ line.sellable_type, line.sellable_id ]) }
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
        unless discount.applies_to_all?
          # Verify lines still exist before creating discount items
          # (lines may have been destroyed between matching and this call)
          valid_line_ids = verify_line_ids_exist(matching_lines.map(&:id))
          valid_lines = matching_lines.select { |l| valid_line_ids.include?(l.id) }

          create_discount_items_bulk(od, valid_lines)
        end

        od
      end

      def verify_line_ids_exist(line_ids)
        return [] if line_ids.empty?

        # Efficiently check which IDs still exist in the database
        OrderLine.where(id: line_ids).pluck(:id).to_set
      end

      def create_discount_items_bulk(order_discount, matching_lines)
        return if matching_lines.empty?

        # Build records for bulk insert
        records = matching_lines.map do |line|
          {
            order_discount_id: order_discount.id,
            order_line_id: line.id,
            created_at: Time.current,
            updated_at: Time.current
          }
        end

        OrderDiscountItem.insert_all!(records) if records.any?
      end
  end
end
