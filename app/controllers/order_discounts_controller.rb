# frozen_string_literal: true

class OrderDiscountsController < ApplicationController
  before_action :set_order, only: :create
  before_action :set_discount, only: :destroy

  def create
    authorize! :update, @order

    discount = @order.order_discounts.build(discount_params)
    discount.applied_by = current_user
    discount.save!

    # Link specific items if scope is specific_items
    if discount.applies_to_specific_items? && params[:order_line_ids].present?
      params[:order_line_ids].each do |line_id|
        discount.order_discount_items.create!(order_line_id: line_id)
      end
    end

    Orders::CalculateTotals.call(@order)
    Orders::RecordEvent.call(
      order: @order, event_type: "discount_applied", actor: current_user,
      data: { name: discount.name, type: discount.discount_type, value: discount.value.to_s, scope: discount.scope }
    )

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

  def destroy
    order = @discount.order
    authorize! :update, order

    name = @discount.name
    source_discount_id = @discount.discount_id

    # Track overridden store discounts so AutoApply won't re-apply them
    if source_discount_id.present?
      overridden = (order.metadata["overridden_discount_ids"] || []) | [ source_discount_id ]
      order.update_column(:metadata, order.metadata.merge("overridden_discount_ids" => overridden))
    end

    @discount.destroy!

    # Reset line discounts and recalculate
    order.order_lines.update_all(discount_amount: 0)
    Orders::CalculateTotals.call(order)
    Orders::RecordEvent.call(
      order: order, event_type: "discount_removed", actor: current_user,
      data: { name: name }
    )

    respond_to do |format|
      format.turbo_stream {
        render turbo_stream: [
          turbo_stream.replace("order_discounts_panel", partial: "orders/discounts_panel", locals: { order: order.reload }),
          turbo_stream.replace("order_line_items", partial: "orders/line_items", locals: { order: order }),
          turbo_stream.replace("order_totals", partial: "orders/totals_panel", locals: { order: order })
        ]
      }
      format.html { redirect_to edit_order_path(order) }
    end
  end

  private

    def set_order
      @order = Order.find(params[:order_id])
    end

    def set_discount
      @discount = OrderDiscount.find(params[:id])
    end

    def discount_params
      params.require(:order_discount).permit(:name, :discount_type, :value, :scope)
    end
end
