# frozen_string_literal: true

module ReportTemplates
  class DiscountUsage < ReportTemplate
    def self.key         = "discount_usage"
    def self.title       = "Discount usage"
    def self.description = "Shows discount usage over a date range with total reductions, daily breakdowns, and lists all orders using discounts. Held orders shown separately."

    def self.parameters
      [
        { key: :start_date, type: :date, label: "Start date", required: false },
        { key: :end_date,   type: :date, label: "End date",   required: false },
        {
          key: :discount_id,
          type: :select,
          label: "Discount",
          required: false,
          options: discount_options
        }
      ]
    end

    def self.discount_options
      options = [ [ "All discounts", "" ] ]
      Discount.with_discarded.order(:name).each do |discount|
        options << [ discount.name, discount.id.to_s ]
      end
      options
    end

    def self.chart_type = "line"

    def self.table_columns
      [
        { key: :order_number,     label: "Order #" },
        { key: :order_date,       label: "Date" },
        { key: :customer_name,    label: "Customer" },
        { key: :discount_names,   label: "Discount(s)" },
        { key: :discount_amount,  label: "Discount Amount" },
        { key: :order_total,      label: "Order Total" }
      ]
    end

    def self.generate(params)
      start_date = parse_date(params[:start_date], 30.days.ago.to_date)
      end_date   = parse_date(params[:end_date],   Date.current)
      discount_id = params[:discount_id].presence

      date_range = start_date.beginning_of_day..end_date.end_of_day

      # Query completed orders with discounts
      completed_orders_data = fetch_completed_orders(date_range, discount_id)

      # Query held orders with discounts (shown separately, not in summary)
      held_orders_data = fetch_held_orders(date_range, discount_id)

      # Build daily breakdown data
      daily_data = build_daily_breakdown(completed_orders_data, start_date, end_date)

      # Build summary from completed orders only
      summary = build_summary(completed_orders_data, start_date, end_date)

      # Build table data for completed orders
      completed_table = build_table_data(completed_orders_data)

      # Build table data for held orders (separate list)
      held_table = build_table_data(held_orders_data)

      {
        chart: {
          discount_analysis: {
            labels: daily_data[:dates],
            datasets: [
              {
                label: "Order Total (Net)",
                data: daily_data[:order_totals],
                backgroundColor: "rgba(16, 185, 129, 0.3)",
                borderColor: "rgba(16, 185, 129, 1)",
                borderWidth: 2,
                fill: true,
                tension: 0.4,
                stack: "combined"
              },
              {
                label: "Discount Amount",
                data: daily_data[:amounts],
                backgroundColor: "rgba(239, 68, 68, 0.3)",
                borderColor: "rgba(239, 68, 68, 1)",
                borderWidth: 2,
                fill: true,
                tension: 0.4,
                stack: "combined"
              }
            ]
          },
          order_counts: {
            labels: daily_data[:dates],
            datasets: [ {
              label: "Orders with Discounts",
              data: daily_data[:counts],
              backgroundColor: "rgba(59, 130, 246, 0.1)",
              borderColor: "rgba(59, 130, 246, 1)",
              borderWidth: 2,
              fill: true,
              tension: 0.4
            } ]
          }
        },
        table: completed_table,
        held_orders_table: held_table,
        summary: summary
      }
    end

    # ── Private helpers ────────────────────────────────────────────────

    def self.parse_date(value, default)
      return default if value.blank?

      Date.parse(value.to_s)
    rescue ArgumentError
      default
    end
    private_class_method :parse_date

    def self.fetch_completed_orders(date_range, discount_id)
      # Get orders with order-level discounts
      order_discount_orders = Order.kept
        .where(status: :completed)
        .where(completed_at: date_range)
        .joins(:order_discounts)
        .distinct

      # Get orders with line-level discounts
      line_discount_orders = Order.kept
        .where(status: :completed)
        .where(completed_at: date_range)
        .joins(:order_line_discounts)
        .distinct

      # Apply discount filter if specified
      if discount_id.present?
        order_discount_orders = order_discount_orders
          .where(order_discounts: { discount_id: discount_id })

        line_discount_orders = line_discount_orders
          .joins(order_lines: :order_line_discounts)
          .where(order_line_discounts: { source_discount_id: discount_id })
      end

      # Combine and deduplicate
      order_ids = (order_discount_orders.pluck(:id) + line_discount_orders.pluck(:id)).uniq

      Order.kept
        .where(id: order_ids)
        .includes(:customer, :order_discounts, order_lines: :order_line_discounts)
        .order(completed_at: :desc)
    end
    private_class_method :fetch_completed_orders

    def self.fetch_held_orders(date_range, discount_id)
      # Get held orders with order-level discounts
      order_discount_orders = Order.kept
        .where(status: :held)
        .where(created_at: date_range)
        .joins(:order_discounts)
        .distinct

      # Get held orders with line-level discounts
      line_discount_orders = Order.kept
        .where(status: :held)
        .where(created_at: date_range)
        .joins(:order_line_discounts)
        .distinct

      # Apply discount filter if specified
      if discount_id.present?
        order_discount_orders = order_discount_orders
          .where(order_discounts: { discount_id: discount_id })

        line_discount_orders = line_discount_orders
          .joins(order_lines: :order_line_discounts)
          .where(order_line_discounts: { source_discount_id: discount_id })
      end

      # Combine and deduplicate
      order_ids = (order_discount_orders.pluck(:id) + line_discount_orders.pluck(:id)).uniq

      Order.kept
        .where(id: order_ids)
        .includes(:customer, :order_discounts, order_lines: :order_line_discounts)
        .order(created_at: :desc)
    end
    private_class_method :fetch_held_orders

    def self.build_daily_breakdown(orders, start_date, end_date)
      all_dates = (start_date..end_date).map { |d| d.strftime("%b %d") }

      # Initialize daily totals
      daily_amounts = Hash.new(0)
      daily_order_totals = Hash.new(0)
      daily_counts = Hash.new(0)

      orders.each do |order|
        date_key = order.completed_at.strftime("%b %d")

        # Calculate total discount for this order
        order_discount_total = order.order_discounts.sum(&:calculated_amount)
        line_discount_total = order.order_line_discounts.sum(&:calculated_amount)
        total_discount = order_discount_total + line_discount_total

        # Net order total (after discount)
        net_order_total = order.total - total_discount

        daily_amounts[date_key] += total_discount
        daily_order_totals[date_key] += net_order_total
        daily_counts[date_key] += 1
      end

      # Build arrays matching all_dates order
      amounts = all_dates.map { |d| daily_amounts[d] || 0 }
      order_totals = all_dates.map { |d| daily_order_totals[d] || 0 }
      counts = all_dates.map { |d| daily_counts[d] || 0 }

      { dates: all_dates, amounts: amounts, order_totals: order_totals, counts: counts }
    end
    private_class_method :build_daily_breakdown

    def self.build_summary(orders, start_date, end_date)
      total_discount = 0
      total_orders = orders.size

      orders.each do |order|
        order_discount_total = order.order_discounts.sum(&:calculated_amount)
        line_discount_total = order.order_line_discounts.sum(&:calculated_amount)
        total_discount += order_discount_total + line_discount_total
      end

      average_discount = total_orders > 0 ? total_discount / total_orders : 0

      {
        total_discount_amount: format_currency(total_discount),
        total_orders: total_orders.to_s,
        average_discount_per_order: format_currency(average_discount),
        date_range: "#{start_date.strftime('%b %d, %Y')} – #{end_date.strftime('%b %d, %Y')}"
      }
    end
    private_class_method :build_summary

    def self.build_table_data(orders)
      orders.map do |order|
        # Get all discount names
        order_discount_names = order.order_discounts.map(&:name)
        line_discount_names = order.order_line_discounts.map(&:name)
        all_discount_names = (order_discount_names + line_discount_names).uniq

        # Calculate discount amount
        order_discount_total = order.order_discounts.sum(&:calculated_amount)
        line_discount_total = order.order_line_discounts.sum(&:calculated_amount)
        total_discount = order_discount_total + line_discount_total

        # Determine date field based on order status
        order_date = if order.completed?
          order.completed_at
        else
          order.created_at
        end

        {
          order_id: order.id,
          order_number: order.number,
          order_date: order_date.strftime("%b %d, %Y %l:%M %p"),
          customer_name: order.customer_name,
          discount_names: all_discount_names.join(", "),
          discount_amount: format_currency(total_discount),
          order_total: format_currency(order.total)
        }
      end
    end
    private_class_method :build_table_data

    def self.format_currency(amount)
      return "$0.00" if amount.nil? || amount.zero?

      "$#{format('%.2f', amount)}"
    end
    private_class_method :format_currency

    register!
  end
end
