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

    respond_to do |format|
      format.turbo_stream {
        render turbo_stream: [
          turbo_stream.replace("order_discounts_panel", partial: "orders/discounts_panel", locals: { order: @order.reload }),
          turbo_stream.replace("order_line_items", partial: "orders/line_items", locals: { order: @order }),
          turbo_stream.replace("order_totals", partial: "orders/totals_panel", locals: { order: @order })
        ]
      }
      format.html { redirect_to edit_order_path(@order) }
    end
  end

  private

    def set_order
      @order = Order.find(params[:order_id])
    end
end
