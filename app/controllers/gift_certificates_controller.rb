# frozen_string_literal: true

class GiftCertificatesController < ApplicationController
  before_action :set_order, only: %i[new create]

  def new
    authorize! :new, GiftCertificate
    @gift_certificate = GiftCertificate.new
  end

  def create
    authorize! :create, GiftCertificate

    @gift_certificate = GiftCertificate.new(gift_certificate_params)
    @gift_certificate.issued_by = current_user

    if @gift_certificate.save
      line = @order.order_lines.build
      line.snapshot_from_sellable!(@gift_certificate, customer_tax_code: nil)
      line.quantity = 1
      line.save!

      Orders::CalculateTotals.call(@order)

      respond_to do |format|
        format.turbo_stream {
          render turbo_stream: [
            turbo_stream.replace("order_line_items", partial: "orders/line_items", locals: { order: @order.reload }),
            turbo_stream.replace("order_discounts_panel", partial: "orders/discounts_panel", locals: { order: @order }),
            turbo_stream.replace("order_totals", partial: "orders/totals_panel", locals: { order: @order }),
            turbo_stream.replace("order_action_buttons", partial: "register/action_buttons", locals: { order: @order }),
            turbo_stream.replace("gift_cert_modal", partial: "gift_certificates/modal_closed")
          ]
        }
        format.html { redirect_to register_path(order_id: @order.id) }
      end
    else
      respond_to do |format|
        format.turbo_stream {
          render turbo_stream: turbo_stream.replace("gift_cert_modal",
            partial: "gift_certificates/form",
            locals: { order: @order, gift_certificate: @gift_certificate })
        }
        format.html { render :new, status: :unprocessable_entity }
      end
    end
  end

  def lookup
    authorize! :lookup, GiftCertificate
    code = params[:code].to_s.strip.upcase
    gc = GiftCertificate.find_redeemable(code)

    if gc
      render json: {
        found: true,
        code: gc.code,
        balance: gc.remaining_balance.to_f,
        balance_formatted: ActionController::Base.helpers.number_to_currency(gc.remaining_balance)
      }
    else
      render json: { found: false }
    end
  end

  private

    def set_order
      @order = Order.find(params[:order_id])
    end

    def gift_certificate_params
      params.require(:gift_certificate).permit(:initial_amount, :customer_id)
    end
end
