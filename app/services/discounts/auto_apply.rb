# frozen_string_literal: true

module Discounts
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

      # Remove existing auto-applied discounts so they can be re-evaluated
      @order.order_discounts
            .where.not(discount_id: nil)
            .where.not(discount_id: overridden_ids)
            .each(&:destroy)

      # Reload to get current state of lines (important when called after a destroy)
      @current_lines = @order.order_lines.reload.to_a

      active_discounts = Discount.currently_active.where.not(id: overridden_ids)

      active_discounts.each do |discount|
        matching_lines = find_matching_lines(discount)
        next if matching_lines.empty?

        od_scope = discount.applies_to_all? ? :all_items : :specific_items

        od = @order.order_discounts.create!(
          name: discount.name,
          discount_type: ORDER_DISCOUNT_TYPE_MAP[discount.discount_type],
          value: discount.value,
          scope: od_scope,
          discount_id: discount.id,
          applied_by: nil
        )

        next if discount.applies_to_all?

        matching_lines.each { |line| od.order_discount_items.create!(order_line: line) }
      end
    end

    private

      def find_matching_lines(discount)
        return @current_lines if discount.applies_to_all?

        sellable_map = discount.discount_items.group_by(&:discountable_type)
        @current_lines.select do |line|
          sellable_map[line.sellable_type]&.any? { |di| di.discountable_id == line.sellable_id }
        end
      end
  end
end
