# frozen_string_literal: true

class GiftCertificatesController < ApplicationController
  before_action :set_order, only: :create

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

      redirect_to register_path(order_id: @order.id)
    else
      redirect_to register_path(order_id: @order.id), alert: @gift_certificate.errors.full_messages.to_sentence
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
