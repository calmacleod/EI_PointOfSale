# frozen_string_literal: true

class OrderDiscountOverridesController < ApplicationController
  before_action :set_order

  def destroy
    authorize! :update, @order

    discount_id = params[:id].to_i
    overridden = ((@order.metadata["overridden_discount_ids"] || []) - [ discount_id ])
    @order.update_column(:metadata, @order.metadata.merge("overridden_discount_ids" => overridden))

    Discounts::AutoApply.call(@order)
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
