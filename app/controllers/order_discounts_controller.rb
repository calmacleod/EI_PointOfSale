# frozen_string_literal: true

# Controller for managing order-level discounts.
# Note: Line-level discounts are managed via OrderLineDiscountsController.
class OrderDiscountsController < ApplicationController
  before_action :set_order, only: :create
  before_action :set_discount, only: :destroy

  def create
    authorize! :update, @order

    # Only allow order-level discounts through this controller
    discount = @order.order_discounts.build(discount_params.merge(scope: :all_items))
    discount.applied_by = current_user
    discount.save!

    Orders::CalculateTotals.call(@order)
    Orders::RecordEvent.call(
      order: @order, event_type: "discount_applied", actor: current_user,
      data: { name: discount.name, type: discount.discount_type, value: discount.value.to_s, scope: discount.scope }
    )

    redirect_to register_path(order_id: @order.id)
  end

  def destroy
    order = @discount.order
    authorize! :update, order

    name = @discount.name

    @discount.destroy!

    Orders::CalculateTotals.call(order)
    Orders::RecordEvent.call(
      order: order, event_type: "discount_removed", actor: current_user,
      data: { name: name }
    )

    redirect_to register_path(order_id: order.id)
  end

  private

    def set_order
      @order = Order.find(params[:order_id])
    end

    def set_discount
      @discount = OrderDiscount.find(params[:id])
    end

    def discount_params
      params.require(:order_discount).permit(:name, :discount_type, :value)
    end
end
