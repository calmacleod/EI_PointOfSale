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

      # Load current state in minimal queries
      current_lines = load_order_lines
      existing_order_discounts = load_existing_order_discounts
      existing_line_discounts = load_existing_line_discounts

      # Sync customer automatic discount (handles both order-level and per-item)
      sync_customer_discount(current_lines, existing_order_discounts, existing_line_discounts)

      # Sync order-level discounts (applies_to_all, excluding customer discounts already handled)
      sync_order_level_discounts(existing_order_discounts)

      # Sync line-level discounts (specific items, including fixed_total with specific items)
      sync_line_level_discounts(current_lines, existing_line_discounts)
    end

    private

      def load_order_lines
        @order.order_lines.to_a
      end

      def load_existing_order_discounts
        @order.order_discounts.where.not(discount_id: nil).to_a
      end

      def sync_customer_discount(lines, existing_order_discounts, existing_line_discounts)
        customer = @order.customer
        customer_discount_id = customer&.discount_id
        customer_discount = customer&.discount

        # Find ALL existing customer discounts on the order (discounts associated with any customer)
        # Use customers.any? to find any discount that belongs to a customer
        existing_customer_order_discounts = existing_order_discounts.select do |od|
          od.discount&.customers&.any?
        end

        existing_customer_line_discounts = existing_line_discounts.select do |ld|
          ld.source_discount&.customers&.any?
        end

        if customer_discount_id && customer_discount
          # Check if it's a per-item discount (needs deny-list check)
          if customer_discount.per_item_discount?
            # For per-item discounts, apply as line-level discounts with deny-list check
            sync_customer_per_item_discount(customer_discount, lines, existing_customer_line_discounts)
            # Remove any existing order-level customer discounts (shouldn't exist but clean up)
            existing_customer_order_discounts.each(&:destroy)
          else
            # For fixed_total discounts, apply as order-level discount
            # First remove any existing customer discounts that aren't the current one
            existing_customer_order_discounts.each do |od|
              od.destroy unless od.discount_id == customer_discount_id
            end

            # Create new order-level discount if not already present
            if existing_order_discounts.none? { |od| od.discount_id == customer_discount_id }
              create_customer_order_discount(customer_discount)
            end
            # Clean up any existing line-level discounts for customer discounts
            existing_customer_line_discounts.each(&:destroy)
          end
        else
          # No customer or no customer discount - remove ALL customer discounts
          existing_customer_order_discounts.each(&:destroy)
          existing_customer_line_discounts.each(&:destroy)
        end
      end

      def sync_customer_per_item_discount(discount, lines, existing_line_discounts)
        # Check deny-list for each line and create discounts for allowed lines
        # Gift certificates are never eligible for discounts
        allowed_lines = lines.reject do |line|
          line.sellable_type == "GiftCertificate" || discount.denies?(line.sellable)
        end

        allowed_lines.each do |line|
          next unless line.persisted?

          existing = existing_line_discounts.find { |ld| ld.order_line_id == line.id }

          if existing
            restore_if_excluded(existing)
          else
            line.order_line_discounts.create!(
              source_discount: discount,
              name: discount.name,
              discount_type: ORDER_DISCOUNT_TYPE_MAP[discount.discount_type],
              value: discount.value,
              calculated_amount: 0,
              auto_applied: true
            )
          end
        end

        # Remove discounts for lines that are now denied
        line_ids = allowed_lines.map(&:id)
        existing_line_discounts.each do |existing|
          unless line_ids.include?(existing.order_line_id) || existing.excluded?
            existing.destroy!
          end
        end
      end

      def create_customer_order_discount(discount)
        @order.order_discounts.create!(
          name: discount.name,
          discount_type: ORDER_DISCOUNT_TYPE_MAP[discount.discount_type],
          value: discount.value,
          scope: :all_items,
          discount_id: discount.id,
          applied_by: nil
        )
      end

      def load_existing_line_discounts
        @order.order_line_discounts.where(auto_applied: true).to_a
      end

      def sync_order_level_discounts(existing_discounts)
        applicable = find_applicable_order_level_discounts

        # Get customer discount ID if customer has one
        customer_discount_id = @order.customer&.discount_id

        # Determine changes needed
        # Don't remove customer discounts - they are handled separately
        to_remove = existing_discounts.reject do |od|
          applicable.key?(od.discount_id) || od.discount_id == customer_discount_id
        end
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

        # Get applicable discounts for lines (applies_to_all: false only)
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
        # BUT exclude discounts associated with customers (handled separately by sync_customer_discount)
        applicable_discount_ids = applicable_discounts.keys.map(&:id)
        existing_line_discounts.each do |line_discount|
          next if applicable_discount_ids.include?(line_discount.source_discount_id)
          # Skip customer discounts - they are managed by sync_customer_discount
          next if line_discount.source_discount&.customers&.any?

          line_discount.destroy!
        end
      end

      def find_applicable_order_level_discounts
        {}.tap do |applicable|
          # Get all order-level discounts (applies_to_all: true)
          # BUT exclude ALL discounts that have customers (handled separately by sync_customer_discount)
          Discount.currently_active
            .where(applies_to_all: true)
            .where.not(id: Discount.joins(:customers).select(:id))
            .find_each do |discount|
              applicable[discount.id] = discount
            end
        end
      end

      def find_applicable_line_level_discounts(lines)
        {}.tap do |applicable|
          # All discounts with specific allow lists (applies_to_all: false)
          Discount.currently_active
            .where(applies_to_all: false)
            .includes(discount_items: :discountable)
            .find_each do |discount|
              matching_lines = find_matching_lines(discount, lines)
              applicable[discount] = matching_lines unless matching_lines.empty?
            end
        end
      end

      def find_matching_lines(discount, lines)
        allowed_set = build_discountable_set(discount.allowed_items)
        denied_set = build_discountable_set(discount.denied_items)

        lines.select do |line|
          sellable = line.sellable
          sellable_type = line.sellable_type
          sellable_id = sellable.id

          # Gift certificates are never eligible for discounts
          next false if sellable_type == "GiftCertificate"

          # Check deny-list first (takes precedence)
          next false if denied_set.include?([ sellable_type, sellable_id ])

          # Check ProductGroup deny-list for Products
          if sellable.respond_to?(:product_group) && sellable.product_group.present?
            next false if denied_set.include?([ "ProductGroup", sellable.product_group_id ])
          end

          # Check allow-list directly
          next true if allowed_set.include?([ sellable_type, sellable_id ])

          # Check ProductGroup allow-list for Products
          if sellable.respond_to?(:product_group) && sellable.product_group.present?
            next true if allowed_set.include?([ "ProductGroup", sellable.product_group_id ])
          end

          false
        end
      end

      def build_discountable_set(discount_items)
        discount_items.each_with_object(Set.new) do |item, set|
          set.add([ item.discountable_type, item.discountable_id ])
        end
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
