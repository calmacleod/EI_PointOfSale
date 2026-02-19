# frozen_string_literal: true

# Controller for managing per-line discounts with unit-level granularity.
# Allows creating manual discounts, excluding/restoring discounts from specific units,
# and destroying manual discounts.
class OrderLineDiscountsController < ApplicationController
  before_action :set_order, only: :create
  before_action :set_line_discount, only: %i[exclude restore destroy]

  # Create a manual line discount applied to selected units across one or more order lines.
  # Expects line_quantities: { line_id => applied_unit_count } built by the discount-modal
  # Stimulus controller from the unit-toggle buttons.
  def create
    authorize! :update, @order

    attrs = line_discount_params
    line_quantities = params.dig(:order_line_discount, :line_quantities)&.to_unsafe_h || {}

    line_quantities.each do |line_id, applied_count|
      line = @order.order_lines.find(line_id)
      next if line.sellable_type == "GiftCertificate"

      applied = applied_count.to_i.clamp(0, line.quantity)
      next if applied.zero?

      line.order_line_discounts.create!(
        attrs.merge(auto_applied: false, excluded_quantity: line.quantity - applied)
      )
    end

    Orders::CalculateTotals.call(@order)
    Orders::RecordEvent.call(
      order: @order, event_type: "discount_applied", actor: current_user,
      data: { name: attrs[:name], type: attrs[:discount_type], value: attrs[:value].to_s, scope: "specific_items" }
    )

    respond_to do |format|
      format.turbo_stream {
        render turbo_stream: [
          turbo_stream.replace("order_discounts_panel", partial: "orders/discounts_panel", locals: { order: @order.reload }),
          turbo_stream.replace("order_line_items", partial: "orders/line_items", locals: { order: @order }),
          turbo_stream.replace("order_totals", partial: "orders/totals_panel", locals: { order: @order })
        ]
      }
      format.html { redirect_to edit_order_path(@order) }
    end
  end

  # Destroy a manual line discount (auto-applied discounts are managed via exclude/restore)
  def destroy
    order = @line_discount.order_line.order
    authorize! :update, order

    name = @line_discount.name
    @line_discount.destroy!

    Orders::CalculateTotals.call(order)
    Orders::RecordEvent.call(
      order: order, event_type: "discount_removed", actor: current_user,
      data: { name: name }
    )

    respond_to do |format|
      format.turbo_stream {
        render turbo_stream: [
          turbo_stream.replace("order_discounts_panel", partial: "orders/discounts_panel", locals: { order: order.reload }),
          turbo_stream.replace("order_line_items", partial: "orders/line_items", locals: { order: order }),
          turbo_stream.replace("order_totals", partial: "orders/totals_panel", locals: { order: order })
        ]
      }
      format.html { redirect_to edit_order_path(order) }
    end
  end

  # Exclude discount from one more unit
  def exclude
    order = @line_discount.order_line.order
    authorize! :update, order

    @line_discount.exclude_one!
    Orders::CalculateTotals.call(order)

    respond_to do |format|
      format.turbo_stream {
        render turbo_stream: [
          turbo_stream.replace("order_line_#{@line_discount.order_line_id}",
                              partial: "orders/line_item",
                              locals: { line: @line_discount.order_line.reload }),
          turbo_stream.replace("order_discounts_panel",
                              partial: "orders/discounts_panel",
                              locals: { order: order.reload }),
          turbo_stream.replace("order_totals",
                              partial: "orders/totals_panel",
                              locals: { order: order })
        ]
      }
      format.html { redirect_to edit_order_path(order) }
    end
  end

  # Restore discount to one more unit
  def restore
    order = @line_discount.order_line.order
    authorize! :update, order

    @line_discount.restore_one!
    Orders::CalculateTotals.call(order)

    respond_to do |format|
      format.turbo_stream {
        render turbo_stream: [
          turbo_stream.replace("order_line_#{@line_discount.order_line_id}",
                              partial: "orders/line_item",
                              locals: { line: @line_discount.order_line.reload }),
          turbo_stream.replace("order_discounts_panel",
                              partial: "orders/discounts_panel",
                              locals: { order: order.reload }),
          turbo_stream.replace("order_totals",
                              partial: "orders/totals_panel",
                              locals: { order: order })
        ]
      }
      format.html { redirect_to edit_order_path(order) }
    end
  end

  private

    def set_order
      @order = Order.find(params[:order_id])
    end

    def set_line_discount
      @line_discount = OrderLineDiscount.find(params[:id])
    end

    def line_discount_params
      params.require(:order_line_discount).permit(:name, :discount_type, :value)
    end
end
