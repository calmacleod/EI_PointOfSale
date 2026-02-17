# frozen_string_literal: true

# The Register is the cashier's primary workspace — the POS screen.
# GET /register shows the active order form, switching between orders via ?order_id=.
class RegisterController < ApplicationController
  def show
    authorize! :show, :register
    @order = if params[:order_id].present?
      Order.active.find_by(id: params[:order_id]) || find_or_create_draft
    else
      find_or_create_draft
    end

    @order.order_lines.includes(:sellable).order(:position)
    @active_orders = Order.active.includes(:order_lines, :customer).order(created_at: :desc)
    @customers = Customer.kept.order(:name)
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
