# frozen_string_literal: true

class OrdersController < ApplicationController
  include Filterable

  authorize_resource

  before_action :set_order, only: %i[show edit update hold resume complete cancel assign_customer remove_customer receipt refund_form process_refund]

  def index
    @filter_config = FilterConfig.new(:orders, orders_path,
                                      sort_default: "created_at", sort_default_direction: "desc",
                                      search_placeholder: "Search orders...") do |f|
      f.select :status, label: "Status",
               options: Order.statuses.keys.map { |s| [ s.humanize, s ] }
      f.date_range :created_at, label: "Created"
      f.date_range :completed_at, label: "Completed"

      f.column :number,       label: "Order #",   default: true, sortable: true, width: "8rem"
      f.column :status,       label: "Status",     default: true, sortable: true, width: "7rem"
      f.column :customer,     label: "Customer",   default: true,                 width: "12rem"
      f.column :items_count,  label: "Items",      default: true,                 width: "4rem"
      f.column :total,        label: "Total",      default: true, sortable: true, width: "6rem"
      f.column :created_by,   label: "Cashier",    default: true,                 width: "8rem"
      f.column :created_at,   label: "Created",    default: true, sortable: true, width: "10rem"
      f.column :completed_at, label: "Completed",  default: false, sortable: true, width: "10rem"
    end
    @saved_queries = current_user.saved_queries.for_resource("orders")

    @pagy, @orders = filter_and_paginate(
      Order.kept.where.not(status: :draft).includes(:customer, :created_by, :order_lines),
      config: @filter_config
    )
  end

  def show
    @order = @order.tap { |o| o.order_lines.includes(:sellable) }
  end

  def new
    redirect_to register_path
  end

  def create
    @order = Order.create!(
      created_by: current_user,
      status: :draft
    )
    Orders::RecordEvent.call(order: @order, event_type: "created", actor: current_user)
    redirect_to register_path(order_id: @order.id)
  end

  def edit
    redirect_to register_path(order_id: @order.id)
  end

  def update
    if @order.update(order_params)
      redirect_to register_path(order_id: @order.id), notice: "Order updated."
    else
      @order.order_lines.includes(:sellable).order(:position)
      @active_orders = Order.active.includes(:order_lines).order(created_at: :desc)
      @customers = Customer.kept.order(:name)
      render "register/show", status: :unprocessable_entity
    end
  end

  def hold
    Orders::Hold.call(order: @order, actor: current_user)
    redirect_to register_path(order_id: @order.id), notice: "Order put on hold."
  rescue ArgumentError => e
    redirect_to register_path(order_id: @order.id), alert: e.message
  end

  def resume
    Orders::Resume.call(order: @order, actor: current_user)
    redirect_to register_path(order_id: @order.id), notice: "Order resumed."
  rescue ArgumentError => e
    redirect_to register_path(order_id: @order.id), alert: e.message
  end

  def cancel
    unless @order.draft? || @order.held?
      redirect_to register_path, alert: "Only draft or held orders can be cancelled."
      return
    end

    Orders::RecordEvent.call(order: @order, event_type: "cancelled", actor: current_user)
    @order.update!(status: :voided)
    @order.discard!
    redirect_to register_path, notice: "Order #{@order.number} cancelled."
  end

  def complete
    result = Orders::Complete.call(order: @order, actor: current_user)

    if result.success?
      redirect_to order_path(@order), notice: "Order completed!"
    else
      redirect_to register_path(order_id: @order.id), alert: result.errors.join(", ")
    end
  end

  def assign_customer
    customer = Customer.find(params[:customer_id])
    @order.update!(customer: customer)
    Orders::CalculateTotals.call(@order)
    Orders::RecordEvent.call(
      order: @order, event_type: "customer_assigned", actor: current_user,
      data: { customer_name: customer.name, customer_id: customer.id }
    )

    respond_to do |format|
      format.turbo_stream {
        render turbo_stream: [
          turbo_stream.replace("order_customer_panel", partial: "orders/customer_panel", locals: { order: @order }),
          turbo_stream.replace("order_totals", partial: "orders/totals_panel", locals: { order: @order }),
          turbo_stream.replace("order_line_items", partial: "orders/line_items", locals: { order: @order })
        ]
      }
      format.html { redirect_to register_path(order_id: @order.id) }
    end
  end

  def remove_customer
    @order.update!(customer: nil)
    Orders::CalculateTotals.call(@order)
    Orders::RecordEvent.call(
      order: @order, event_type: "customer_removed", actor: current_user
    )

    respond_to do |format|
      format.turbo_stream {
        render turbo_stream: [
          turbo_stream.replace("order_customer_panel", partial: "orders/customer_panel", locals: { order: @order }),
          turbo_stream.replace("order_totals", partial: "orders/totals_panel", locals: { order: @order }),
          turbo_stream.replace("order_line_items", partial: "orders/line_items", locals: { order: @order })
        ]
      }
      format.html { redirect_to register_path(order_id: @order.id) }
    end
  end

  def receipt
    @receipt_lines = Orders::GenerateReceipt.call(@order)
    @template = ReceiptTemplate.current
    @store = Store.current
  end

  def refund_form
    authorize! :process_refund, @order
  end

  def process_refund
    authorize! :process_refund, @order

    line_params = (params[:refund_lines] || []).select { |lp| lp[:selected] == "1" }.map do |lp|
      { order_line_id: lp[:order_line_id], quantity: lp[:quantity], restock: lp[:restock] == "1" }
    end

    result = Orders::ProcessRefund.call(
      order: @order,
      actor: current_user,
      line_params: line_params,
      reason: params[:reason]
    )

    if result.success?
      redirect_to order_path(@order), notice: "Refund #{result.refund.refund_number} processed."
    else
      flash.now[:alert] = result.errors.join(", ")
      render :refund_form, status: :unprocessable_entity
    end
  end

  def held
    scope = Order.held.includes(:customer, :created_by, order_lines: :sellable)

    if params[:search].present?
      search_term = params[:search].strip.downcase
      scope = scope.left_joins(:customer)
        .where("LOWER(orders.number) LIKE :q OR LOWER(orders.notes) LIKE :q OR LOWER(customers.name) LIKE :q", q: "%#{search_term}%")
    end

    scope = scope.where(created_by_id: params[:cashier_id]) if params[:cashier_id].present?

    @held_orders = scope.order(held_at: :desc)
    @cashiers = User.where(id: Order.held.select(:created_by_id).distinct).order(:name)
  end

  def quick_lookup
    code = params[:code].to_s.strip
    @order = Order.find(params[:order_id])

    sellable = Product.find_by_exact_code(code) || Service.kept.find_by(code: code)

    if sellable
      existing_line = @order.order_lines.find_by(sellable: sellable)

      if existing_line
        existing_line.update!(quantity: existing_line.quantity + 1)
        Orders::RecordEvent.call(
          order: @order, event_type: "line_quantity_changed", actor: current_user,
          data: { name: existing_line.name, new_quantity: existing_line.quantity }
        )
      else
        line = @order.order_lines.build(quantity: 1)
        line.snapshot_from_sellable!(sellable, customer_tax_code: @order.customer&.tax_code)
        line.position = (@order.order_lines.maximum(:position) || 0) + 1
        line.save!
        Orders::RecordEvent.call(
          order: @order, event_type: "line_added", actor: current_user,
          data: { name: line.name, code: line.code, quantity: 1, unit_price: line.unit_price.to_s }
        )
      end

      Orders::CalculateTotals.call(@order)

      respond_to do |format|
        format.turbo_stream {
          render turbo_stream: [
            turbo_stream.replace("order_line_items", partial: "orders/line_items", locals: { order: @order.reload }),
            turbo_stream.replace("order_totals", partial: "orders/totals_panel", locals: { order: @order }),
            turbo_stream.update("code_lookup_input", ""),
            turbo_stream.update("lookup_flash", partial: "orders/lookup_flash", locals: { message: "Added #{sellable.sellable_name}", type: :success })
          ]
        }
        format.html { redirect_to register_path(order_id: @order.id) }
      end
    else
      respond_to do |format|
        format.turbo_stream {
          render turbo_stream: [
            turbo_stream.update("lookup_flash", partial: "orders/lookup_flash", locals: { message: "No match for \"#{code}\" — use search", type: :warning })
          ]
        }
        format.html { redirect_to register_path(order_id: @order.id), alert: "No product or service found with code: #{code}" }
      end
    end
  end

  private

    def set_order
      @order = Order.find(params[:id])
    end

    def order_params
      params.require(:order).permit(:notes, :tax_exempt, :tax_exempt_number)
    end
end
