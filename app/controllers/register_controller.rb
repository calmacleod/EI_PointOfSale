# frozen_string_literal: true

# The Register is the cashier's primary workspace — the POS screen.
# GET /register shows the active order form, switching between orders via ?order_id=.
class RegisterController < ApplicationController
  def show
    authorize! :show, :register

    # Eager load all associations needed by the register view in a single query
    base_includes = [
      :customer,
      :created_by,
      { order_lines: :sellable },
      :order_discounts,
      :order_payments
    ]

    @order = if params[:order_id].present?
      Order.active.includes(base_includes).find_by(id: params[:order_id]) || find_or_create_draft
    else
      find_or_create_draft
    end

    # Eager load all needed associations for the tab bar (active orders)
    # Limit to: all draft orders + held orders that are currently open in tabs
    # This prevents showing ALL held orders from the entire system in the tab bar
    draft_orders = Order.draft.includes(
      :customer,
      { order_lines: :sellable },
      :order_discounts,
      :order_payments
    ).order(created_at: :desc)

    # For held orders, only show the current order (if it's held) to avoid tab bar clutter
    held_orders = Order.held.where(id: @order.id).includes(
      :customer,
      { order_lines: :sellable },
      :order_discounts,
      :order_payments
    )

    @active_orders = (draft_orders.to_a + held_orders.to_a).sort_by(&:created_at).reverse

    # NOTE: We do NOT load all customers here - the customer search uses AJAX via search_customers_path
    # This prevents loading thousands of customers into memory on every register page load
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
