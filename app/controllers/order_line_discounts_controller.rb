# frozen_string_literal: true

# Controller for managing per-line discounts with unit-level granularity.
# Allows excluding/restoring discounts from specific units within a quantity stack.
class OrderLineDiscountsController < ApplicationController
  before_action :set_line_discount

  # Exclude discount from one more unit
  def exclude
    order = @line_discount.order_line.order
    authorize! :update, order

    @line_discount.exclude_one!
    Orders::CalculateTotals.call(order)

    respond_to do |format|
      format.turbo_stream {
        render turbo_stream: [
          turbo_stream.replace("order_line_#{@line_discount.order_line_id}",
                              partial: "orders/line_item",
                              locals: { line: @line_discount.order_line }),
          turbo_stream.replace("order_discounts_panel",
                              partial: "orders/discounts_panel",
                              locals: { order: order.reload }),
          turbo_stream.replace("order_totals",
                              partial: "orders/totals_panel",
                              locals: { order: order })
        ]
      }
      format.html { redirect_to edit_order_path(order) }
    end
  end

  # Restore discount to one more unit
  def restore
    order = @line_discount.order_line.order
    authorize! :update, order

    @line_discount.restore_one!
    Orders::CalculateTotals.call(order)

    respond_to do |format|
      format.turbo_stream {
        render turbo_stream: [
          turbo_stream.replace("order_line_#{@line_discount.order_line_id}",
                              partial: "orders/line_item",
                              locals: { line: @line_discount.order_line }),
          turbo_stream.replace("order_discounts_panel",
                              partial: "orders/discounts_panel",
                              locals: { order: order.reload }),
          turbo_stream.replace("order_totals",
                              partial: "orders/totals_panel",
                              locals: { order: order })
        ]
      }
      format.html { redirect_to edit_order_path(order) }
    end
  end

  private

    def set_line_discount
      @line_discount = OrderLineDiscount.find(params[:id])
    end
end
