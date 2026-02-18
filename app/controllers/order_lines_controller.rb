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

    respond_to do |format|
      format.turbo_stream {
        render turbo_stream: [
          turbo_stream.replace("order_line_items", partial: "orders/line_items", locals: { order: @order.reload }),
          turbo_stream.replace("order_discounts_panel", partial: "orders/discounts_panel", locals: { order: @order }),
          turbo_stream.replace("order_totals", partial: "orders/totals_panel", locals: { order: @order }),
          turbo_stream.replace("order_payments_panel", partial: "orders/payments_panel", locals: { order: @order })
        ]
      }
      format.html { redirect_to edit_order_path(@order) }
    end
  end

  def update
    authorize! :update, @order_line.order

    old_qty = @order_line.quantity
    @order_line.update!(quantity: params[:order_line][:quantity].to_i)
    Discounts::AutoApply.call(@order_line.order)
    Orders::CalculateTotals.call(@order_line.order)
    Orders::RecordEvent.call(
      order: @order_line.order, event_type: "line_quantity_changed", actor: current_user,
      data: { name: @order_line.name, old_quantity: old_qty, new_quantity: @order_line.quantity }
    )

    order = @order_line.order
    respond_to do |format|
      format.turbo_stream {
        render turbo_stream: [
          turbo_stream.replace("order_line_items", partial: "orders/line_items", locals: { order: order.reload }),
          turbo_stream.replace("order_discounts_panel", partial: "orders/discounts_panel", locals: { order: order }),
          turbo_stream.replace("order_totals", partial: "orders/totals_panel", locals: { order: order }),
          turbo_stream.replace("order_payments_panel", partial: "orders/payments_panel", locals: { order: order })
        ]
      }
      format.html { redirect_to edit_order_path(order) }
    end
  end

  def destroy
    order = @order_line.order
    authorize! :update, order

    name = @order_line.name
    @order_line.destroy!
    Discounts::AutoApply.call(order)
    Orders::CalculateTotals.call(order)
    Orders::RecordEvent.call(
      order: order, event_type: "line_removed", actor: current_user,
      data: { name: name }
    )

    respond_to do |format|
      format.turbo_stream {
        render turbo_stream: [
          turbo_stream.replace("order_line_items", partial: "orders/line_items", locals: { order: order.reload }),
          turbo_stream.replace("order_discounts_panel", partial: "orders/discounts_panel", locals: { order: order }),
          turbo_stream.replace("order_totals", partial: "orders/totals_panel", locals: { order: order }),
          turbo_stream.replace("order_payments_panel", partial: "orders/payments_panel", locals: { order: order })
        ]
      }
      format.html { redirect_to edit_order_path(order) }
    end
  end

  private

    def set_order
      @order = Order.find(params[:order_id])
    end

    def set_order_line
      @order_line = OrderLine.find(params[:id])
    end

    def find_sellable(type, id)
      case type
      when "Product" then Product.kept.find(id)
      when "Service" then Service.kept.find(id)
      else raise ArgumentError, "Unknown sellable type: #{type}"
      end
    end
end
