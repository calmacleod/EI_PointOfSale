# frozen_string_literal: true

class OrderPaymentsController < ApplicationController
  before_action :set_order, only: :create
  before_action :set_payment, only: :destroy

  def create
    authorize! :update, @order

    payment = @order.order_payments.build(payment_params)
    payment.received_by = current_user

    if payment.gift_certificate?
      gc_code = params.dig(:order_payment, :reference).to_s
      gc = GiftCertificate.find_redeemable(gc_code)
      if gc.nil?
        return render_payment_error("Gift certificate not found or not active", @order)
      end
      payment.gift_certificate = gc
    end

    if payment.save
      Orders::RecordEvent.call(
        order: @order, event_type: "payment_added", actor: current_user,
        data: { method: payment.display_method, amount: payment.amount.to_s, reference: payment.reference }
      )

      respond_to do |format|
        format.turbo_stream {
          render turbo_stream: [
            turbo_stream.replace("order_payments_panel", partial: "orders/payments_panel", locals: { order: @order.reload }),
            turbo_stream.replace("order_totals", partial: "orders/totals_panel", locals: { order: @order }),
            turbo_stream.replace("order_action_buttons", partial: "register/action_buttons", locals: { order: @order })
          ]
        }
        format.html { redirect_to edit_order_path(@order) }
      end
    else
      render_payment_error(payment.errors.full_messages.to_sentence, @order)
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
          turbo_stream.replace("order_totals", partial: "orders/totals_panel", locals: { order: order }),
          turbo_stream.replace("order_action_buttons", partial: "register/action_buttons", locals: { order: order })
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
      params.require(:order_payment).permit(:payment_method, :amount, :amount_tendered, :change_given, :reference, :gift_certificate_id)
    end

    def render_payment_error(message, order)
      respond_to do |format|
        format.turbo_stream {
          render turbo_stream: turbo_stream.replace(
            "order_payments_panel",
            partial: "orders/payments_panel",
            locals: { order: order.reload, payment_error: message }
          )
        }
        format.html { redirect_to edit_order_path(order), alert: message }
      end
    end
end
