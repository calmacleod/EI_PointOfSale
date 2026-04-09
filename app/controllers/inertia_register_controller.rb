# frozen_string_literal: true

# Experimental Inertia/React version of the register page.
# Mirrors RegisterController but renders via Inertia with serialized props.
# Accessible at /inertia/register
class InertiaRegisterController < ApplicationController
  layout "inertia"

  def show
    authorize! :show, :register

    base_includes = [
      :customer,
      :created_by,
      { order_lines: [ :sellable, :order_line_discounts ] },
      :order_discounts,
      :order_payments
    ]

    @order = if params[:order_id].present?
      Order.active.includes(base_includes).find_by(id: params[:order_id]) || find_or_create_draft(base_includes)
    else
      find_or_create_draft(base_includes)
    end

    draft_orders = Order.draft.includes(base_includes).order(created_at: :desc)
    held_orders = Order.held.where(id: @order.id).includes(base_includes)
    @active_orders = (draft_orders.to_a + held_orders.to_a).sort_by(&:created_at)
    @held_count = Order.held.count

    render inertia: "Register/Show", props: {
      order: serialize_order(@order),
      active_orders: @active_orders.map { |o| serialize_tab(o) },
      held_count: @held_count,
      routes: route_map(@order)
    }
  end

  def new_order
    authorize! :new_order, :register
    order = Order.create!(created_by: current_user, status: :draft)
    Orders::RecordEvent.call(order: order, event_type: "created", actor: current_user)
    redirect_to inertia_register_path(order_id: order.id)
  end

  def hold
    order = find_order_from_params
    authorize! :hold, order
    Orders::Hold.call(order: order, actor: current_user)
    redirect_to inertia_register_path(order_id: order.id), notice: "Order put on hold."
  rescue ArgumentError => e
    redirect_to inertia_register_path(order_id: order.id), alert: e.message
  end

  def resume
    order = find_order_from_params
    authorize! :resume, order
    Orders::Resume.call(order: order, actor: current_user)
    redirect_to inertia_register_path(order_id: order.id), notice: "Order resumed."
  rescue ArgumentError => e
    redirect_to inertia_register_path(order_id: order.id), alert: e.message
  end

  def complete
    order = find_order_from_params
    authorize! :complete, order
    result = Orders::Complete.call(order: order, actor: current_user)
    if result.success?
      redirect_to order_path(order), notice: "Order completed!"
    else
      redirect_to inertia_register_path(order_id: order.id), alert: result.errors.join(", ")
    end
  end

  def cancel
    order = find_order_from_params
    authorize! :cancel, order
    Orders::Cancel.call(order: order, actor: current_user)
    redirect_to inertia_register_path, notice: "Order #{order.number} cancelled."
  rescue ArgumentError => e
    redirect_to inertia_register_path, alert: e.message
  end

  private

    def find_order_from_params
      Order.find(params[:order_id] || params[:id])
    end

    def find_or_create_draft(includes)
      existing = Order.draft.includes(includes).order(created_at: :desc).first
      return existing if existing

      order = Order.create!(created_by: current_user, status: :draft)
      Orders::RecordEvent.call(order: order, event_type: "created", actor: current_user)
      Order.includes(includes).find(order.id)
    end

    def route_map(order)
      {
        new_order: new_order_inertia_register_path,
        quick_lookup: quick_lookup_orders_path,
        order_lines: order_order_lines_path(order),
        order_payments: order_order_payments_path(order),
        order_discounts: order_order_discounts_path(order),
        hold: hold_inertia_register_path(order_id: order.id),
        resume: resume_inertia_register_path(order_id: order.id),
        complete: complete_inertia_register_path(order_id: order.id),
        cancel: cancel_inertia_register_path(order_id: order.id),
        assign_customer: assign_customer_order_path(order),
        remove_customer: remove_customer_order_path(order),
        customer_search: search_customers_path,
        product_search: search_path,
        gift_certificate_lookup: gift_certificate_lookup_path
      }
    end

    def serialize_order(order)
      {
        id: order.id,
        number: order.number,
        status: order.status,
        display_status: order.display_status,
        subtotal: order.subtotal.to_f,
        discount_total: order.discount_total.to_f,
        tax_total: order.tax_total.to_f,
        total: order.total.to_f,
        amount_remaining: order.amount_remaining.to_f,
        amount_paid: order.amount_paid.to_f,
        payment_complete: order.payment_complete?,
        notes: order.notes || "",
        customer: serialize_customer(order.customer),
        created_by: { name: order.created_by.name.presence || order.created_by.email_address },
        order_lines: order.order_lines.map { |l| serialize_line(l) },
        order_payments: order.order_payments.map { |p| serialize_payment(p) },
        order_discounts: order.order_discounts.map { |d| serialize_order_discount(d) }
      }
    end

    def serialize_tab(order)
      {
        id: order.id,
        number: order.number,
        status: order.status,
        customer_name: order.customer_name,
        line_count: order.order_lines.size
      }
    end

    def serialize_customer(customer)
      return nil if customer.nil?
      {
        id: customer.id,
        name: customer.name,
        member_number: customer.member_number,
        tax_code: customer.tax_code ? { name: customer.tax_code.name, rate: customer.tax_code.rate.to_f } : nil
      }
    end

    def serialize_line(line)
      {
        id: line.id,
        code: line.code,
        name: line.name,
        quantity: line.quantity,
        unit_price: line.unit_price.to_f,
        line_total: line.line_total.to_f,
        tax_rate: line.tax_rate.to_f,
        tax_amount: line.tax_amount.to_f,
        discount_amount: line.discount_amount.to_f,
        sellable_type: line.sellable_type,
        sellable_id: line.sellable_id,
        update_url: order_line_path(line),
        delete_url: order_line_path(line),
        line_discounts: line.order_line_discounts.map { |d| serialize_line_discount(d) }
      }
    end

    def serialize_line_discount(d)
      {
        id: d.id,
        name: d.name,
        calculated_amount: d.calculated_amount.to_f,
        auto_applied: d.auto_applied
      }
    end

    def serialize_payment(payment)
      {
        id: payment.id,
        payment_method: payment.payment_method,
        display_method: payment.display_method,
        amount: payment.amount.to_f,
        amount_tendered: payment.amount_tendered&.to_f,
        change_given: payment.change_given&.to_f,
        reference: payment.reference,
        delete_url: order_payment_path(payment)
      }
    end

    def serialize_order_discount(d)
      {
        id: d.id,
        name: d.name,
        display_value: d.display_value,
        calculated_amount: d.calculated_amount.to_f,
        auto_applied: d.auto_applied?,
        delete_url: order_discount_path(d)
      }
    end
end
