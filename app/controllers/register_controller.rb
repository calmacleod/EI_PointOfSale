# frozen_string_literal: true

# The Register is the cashier's primary workspace — the POS screen.
# GET /register shows the active order form, switching between orders via ?order_id=.
class RegisterController < ApplicationController
  REGISTER_INCLUDES = [
    :customer,
    :created_by,
    { order_lines: [ :sellable, :order_line_discounts, :refund_lines ] },
    :order_discounts,
    :order_payments
  ].freeze

  def show
    authorize! :show, :register

    selected_order = if params[:order_id].present?
      Order.active.find_by(id: params[:order_id]) || find_or_create_draft
    else
      find_or_create_draft
    end
    @order = Order.active.includes(*REGISTER_INCLUDES).find(selected_order.id)

    # Tabs need only their customer and line count. Keep unrelated order detail
    # associations out of this frequently rendered collection.
    @active_orders = Order
      .where(status: :draft)
      .or(Order.where(id: @order.id, status: :held))
      .includes(:customer, :order_lines)
      .order(created_at: :desc)
    @held_count = Order.held.count
  end

  def new_order
    authorize! :new_order, :register
    order = Order.create!(created_by: current_user, status: :draft)
    Orders::RecordEvent.call(order: order, event_type: "created", actor: current_user)
    redirect_to register_path(order_id: order.id)
  end

  private

    def find_or_create_draft
      existing = Order.draft.order(created_at: :desc).first
      return existing if existing

      order = Order.create!(created_by: current_user, status: :draft)
      Orders::RecordEvent.call(order: order, event_type: "created", actor: current_user)
      order
    end
end
