# frozen_string_literal: true

module ReportTemplates
  class SalesSummary < ReportTemplate
    TABLE_LIMIT = 2_000
    SALES_STATUSES = %i[completed partially_refunded refunded].freeze

    def self.key         = "sales_summary"
    def self.title       = "Sales summary"
    def self.description = "Summarizes completed sales over a date range with daily revenue, discounts, tax, refunds, and order-level detail."

    def self.parameters
      [
        { key: :start_date, type: :date, label: "Start date", required: false },
        { key: :end_date,   type: :date, label: "End date",   required: false }
      ]
    end

    def self.chart_type = "line"

    def self.table_columns
      [
        { key: :order_number, label: "Order #" },
        { key: :completed_at, label: "Completed" },
        { key: :customer,     label: "Customer" },
        { key: :items,        label: "Items" },
        { key: :subtotal,     label: "Subtotal" },
        { key: :discount,     label: "Discount" },
        { key: :tax,          label: "Tax" },
        { key: :refunds,      label: "Refunds" },
        { key: :net_total,    label: "Net total" }
      ]
    end

    def self.generate(params)
      start_date, end_date = report_date_range(params)
      orders = fetch_orders(start_date, end_date)
      refunds = fetch_refunds(start_date, end_date)
      refund_totals_by_order_id = refunds.group(:order_id).sum(:total)

      table_data = build_table_data(orders, refund_totals_by_order_id)
      daily_data = build_daily_data(orders, refunds, start_date, end_date)

      {
        chart: {
          labels: daily_data[:labels],
          datasets: [
            chart_dataset("Net sales", daily_data[:net_sales], "rgba(16, 185, 129, 1)", "rgba(16, 185, 129, 0.15)"),
            chart_dataset("Tax collected", daily_data[:tax], "rgba(59, 130, 246, 1)", "rgba(59, 130, 246, 0.12)"),
            chart_dataset("Refunds", daily_data[:refunds], "rgba(239, 68, 68, 1)", "rgba(239, 68, 68, 0.12)")
          ]
        },
        table: table_data.first(TABLE_LIMIT),
        summary: build_summary(orders, refunds, table_data.size, start_date, end_date)
      }
    end

    def self.fetch_orders(start_date, end_date)
      Order.kept
        .where(status: SALES_STATUSES)
        .where(completed_at: start_date.beginning_of_day..end_date.end_of_day)
        .includes(:customer, :order_lines)
        .order(completed_at: :desc)
    end
    private_class_method :fetch_orders

    def self.fetch_refunds(start_date, end_date)
      Refund.where(created_at: start_date.beginning_of_day..end_date.end_of_day)
    end
    private_class_method :fetch_refunds

    def self.build_table_data(orders, refund_totals_by_order_id)
      orders.map do |order|
        refund_total = refund_totals_by_order_id[order.id].to_d
        {
          order_id: order.id,
          order_number: order.number,
          completed_at: order.completed_at&.strftime("%b %d, %Y %l:%M %p"),
          customer: order.customer_name,
          items: order.order_lines.sum(&:quantity),
          subtotal: format_currency(order.subtotal),
          discount: format_currency(order.discount_total),
          tax: format_currency(order.tax_total),
          refunds: format_currency(refund_total),
          net_total: format_currency(order.total.to_d - refund_total)
        }
      end
    end
    private_class_method :build_table_data

    def self.build_daily_data(orders, refunds, start_date, end_date)
      labels = (start_date..end_date).map { |date| date.strftime("%b %d") }
      net_sales = Hash.new(0.to_d)
      tax = Hash.new(0.to_d)
      refund_totals = Hash.new(0.to_d)

      orders.each do |order|
        key = order.completed_at.to_date.strftime("%b %d")
        net_sales[key] += order.total.to_d
        tax[key] += order.tax_total.to_d
      end

      refunds.each do |refund|
        key = refund.created_at.to_date.strftime("%b %d")
        refund_totals[key] += refund.total.to_d
        net_sales[key] -= refund.total.to_d
      end

      {
        labels: labels,
        net_sales: labels.map { |label| net_sales[label] },
        tax: labels.map { |label| tax[label] },
        refunds: labels.map { |label| refund_totals[label] }
      }
    end
    private_class_method :build_daily_data

    def self.build_summary(orders, refunds, table_count, start_date, end_date)
      gross_total = orders.sum { |order| order.total.to_d }
      refund_total = refunds.sum { |refund| refund.total.to_d }
      order_count = orders.size

      summary = {
        date_range: format_date_range(start_date, end_date),
        completed_orders: order_count,
        gross_sales: format_currency(gross_total),
        refunds: format_currency(refund_total),
        net_sales: format_currency(gross_total - refund_total),
        tax_collected: format_currency(orders.sum { |order| order.tax_total.to_d }),
        discounts: format_currency(orders.sum { |order| order.discount_total.to_d }),
        average_order: format_currency(order_count.positive? ? gross_total / order_count : 0)
      }
      summary[:table_note] = "Showing first #{TABLE_LIMIT} of #{table_count} orders" if table_count > TABLE_LIMIT
      summary
    end
    private_class_method :build_summary

    def self.chart_dataset(label, data, border_color, background_color)
      {
        label: label,
        data: data,
        borderColor: border_color,
        backgroundColor: background_color,
        borderWidth: 2,
        fill: true,
        tension: 0.35
      }
    end
    private_class_method :chart_dataset

    register!
  end
end
