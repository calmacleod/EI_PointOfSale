# frozen_string_literal: true

class OrderPaymentsController < ApplicationController
  before_action :set_order, only: :create
  before_action :set_payment, only: :destroy

  def create
    authorize! :update, @order

    payment = @order.order_payments.build(payment_params)
    payment.received_by = current_user
    payment.save!

    Orders::RecordEvent.call(
      order: @order, event_type: "payment_added", actor: current_user,
      data: { method: payment.display_method, amount: payment.amount.to_s, reference: payment.reference }
    )

    respond_to do |format|
      format.turbo_stream {
        render turbo_stream: [
          turbo_stream.replace("order_payments_panel", partial: "orders/payments_panel", locals: { order: @order.reload }),
          turbo_stream.replace("order_totals", partial: "orders/totals_panel", locals: { order: @order })
        ]
      }
      format.html { redirect_to edit_order_path(@order) }
    end
  end

  def destroy
    order = @payment.order
    authorize! :update, order

    method_name = @payment.display_method
    amount = @payment.amount
    @payment.destroy!

    Orders::RecordEvent.call(
      order: order, event_type: "payment_removed", actor: current_user,
      data: { method: method_name, amount: amount.to_s }
    )

    respond_to do |format|
      format.turbo_stream {
        render turbo_stream: [
          turbo_stream.replace("order_payments_panel", partial: "orders/payments_panel", locals: { order: order.reload }),
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

    def set_payment
      @payment = OrderPayment.find(params[:id])
    end

    def payment_params
      params.require(:order_payment).permit(:payment_method, :amount, :amount_tendered, :change_given, :reference)
    end
end
