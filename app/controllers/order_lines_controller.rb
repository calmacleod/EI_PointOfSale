# frozen_string_literal: true

class OrderLinesController < ApplicationController
  before_action :set_order, only: :create
  before_action :set_order_line, only: %i[update destroy]

  def create
    authorize! :update, @order

    sellable = find_sellable(params[:sellable_type], params[:sellable_id])

    OrderLines::Add.call(
      order: @order,
      sellable: sellable,
      actor: current_user,
      quantity: params[:quantity] || 1
    )

    redirect_to register_path(order_id: @order.id)
  end

  def update
    authorize! :update, @order_line.order

    old_qty = @order_line.quantity
    new_qty = params[:order_line][:quantity].to_i
    @order_line.update!(quantity: new_qty)
    Discounts::AutoApply.call(@order_line.order)
    Orders::CalculateTotals.call(@order_line.order)
    enqueue_committed_sync(@order_line, new_qty - old_qty)
    Orders::RecordEvent.call(
      order: @order_line.order, event_type: "line_quantity_changed", actor: current_user,
      data: { name: @order_line.name, old_quantity: old_qty, new_quantity: @order_line.quantity }
    )

    redirect_to register_path(order_id: @order_line.order_id)
  end

  def destroy
    order = @order_line.order
    order_id = order.id
    authorize! :update, order

    name = @order_line.name
    qty = @order_line.quantity
    @order_line.destroy!
    enqueue_committed_sync(@order_line, -qty)
    Discounts::AutoApply.call(order)
    Orders::CalculateTotals.call(order)
    Orders::RecordEvent.call(
      order: order, event_type: "line_removed", actor: current_user,
      data: { name: name }
    )

    redirect_to register_path(order_id: order_id)
  end

  private

    def set_order
      @order = Order.find(params[:order_id])
    end

    def set_order_line
      @order_line = OrderLine.find(params[:id])
    end

    def enqueue_committed_sync(line, delta)
      return if delta == 0
      sellable = line.sellable
      return unless sellable.is_a?(Product) && sellable.sync_to_shopify?

      ShopifySync::SyncCommittedJob.perform_later(sellable.id, delta)
    end

    def find_sellable(type, id)
      case type
      when "Product" then Product.kept.find(id)
      when "Service" then Service.kept.find(id)
      else raise ArgumentError, "Unknown sellable type: #{type}"
      end
    end
end
