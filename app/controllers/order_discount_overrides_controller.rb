# frozen_string_literal: true

# Controller for managing discount overrides on a per-line basis.
# Allows restoring auto-applied discounts that were previously excluded.
class OrderDiscountOverridesController < ApplicationController
  before_action :set_order

  # Restore an auto-applied discount to all lines where it was excluded
  def destroy
    authorize! :update, @order

    discount_id = params[:id].to_i

    # Restore all excluded line discounts for this source discount
    restored_count = @order.order_line_discounts
                           .where(source_discount_id: discount_id)
                           .where.not(excluded_at: nil)
                           .update_all(excluded_at: nil)

    # If no line discounts were restored, check if this is an order-level discount
    # that needs to be re-added
    if restored_count == 0
      discount = Discount.find_by(id: discount_id)
      if discount&.applies_to_all?
        Discounts::AutoApply.call(@order)
      end
    end

    Orders::CalculateTotals.call(@order)

    redirect_to register_path(order_id: @order.id)
  end

  private

    def set_order
      @order = Order.find(params[:order_id])
    end
end
