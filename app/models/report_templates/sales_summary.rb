# frozen_string_literal: true

module ReportTemplates
  class SalesSummary < ReportTemplate
    SALES_STATUSES = %i[completed partially_refunded refunded].freeze

    def self.key         = "sales_summary"
    def self.title       = "Sales summary"
    def self.description = "Sales and refunds in the selected period. Receipts include tax. Refunds use the date issued, including returns for older sales; see the separate Refunds table."

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
        { key: :completed_at, label: "Completed", type: :datetime },
        { key: :customer,     label: "Customer" },
        { key: :items,        label: "Items", type: :integer },
        { key: :subtotal,     label: "Subtotal", type: :currency },
        { key: :discount,     label: "Discount", type: :currency },
        { key: :tax,          label: "Tax", type: :currency },
        { key: :refunds,      label: "Refunds", type: :currency },
        { key: :net_total,    label: "Net receipts (incl. tax)", type: :currency }
      ]
    end

    def self.generate(params)
      start_date, end_date = report_date_range(params)
      orders = fetch_orders(start_date, end_date)
      refunds = fetch_refunds(start_date, end_date)
      refund_totals_by_order_id = refunds.reorder(nil).group(:order_id).sum(:total)

      table_data = build_table_data(orders, refund_totals_by_order_id)
      daily_data = build_daily_data(orders, refunds, start_date, end_date)

      {
        chart: {
          labels: daily_data[:labels],
          datasets: [
            chart_dataset("Net receipts (incl. tax)", daily_data[:net_sales], "rgba(16, 185, 129, 1)", "rgba(16, 185, 129, 0.15)"),
            chart_dataset("Tax on sales before refunds", daily_data[:tax], "rgba(59, 130, 246, 1)", "rgba(59, 130, 246, 0.12)"),
            chart_dataset("Refunds", daily_data[:refunds], "rgba(239, 68, 68, 1)", "rgba(239, 68, 68, 0.12)")
          ]
        },
        table: table_data,
        additional_tables: [ refund_table(refunds) ],
        summary: build_summary(orders, refunds, start_date, end_date)
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
      Refund.where(created_at: start_date.beginning_of_day..end_date.end_of_day).includes(:order).order(:created_at, :id)
    end
    private_class_method :fetch_refunds

    def self.refund_table(refunds)
      {
        name: "Refunds",
        columns: [
          { key: :refund_number, label: "Refund #" },
          { key: :order_number, label: "Order #" },
          { key: :refunded_at, label: "Refund date", type: :datetime },
          { key: :total, label: "Refund (incl. tax)", type: :currency }
        ],
        rows: refunds.map do |refund|
          { refund_number: refund.refund_number, order_number: refund.order.number, refunded_at: refund.created_at.iso8601, total: refund.total }
        end
      }
    end
    private_class_method :refund_table

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
      labels = (start_date..end_date).map { |date| date.strftime("%Y-%m-%d") }
      net_sales = Hash.new(0.to_d)
      tax = Hash.new(0.to_d)
      refund_totals = Hash.new(0.to_d)

      orders.each do |order|
        key = order.completed_at.to_date.strftime("%Y-%m-%d")
        net_sales[key] += order.total.to_d
        tax[key] += order.tax_total.to_d
      end

      refunds.each do |refund|
        key = refund.created_at.to_date.strftime("%Y-%m-%d")
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

    def self.build_summary(orders, refunds, start_date, end_date)
      gross_total = orders.sum { |order| order.total.to_d }
      refund_total = refunds.sum { |refund| refund.total.to_d }
      order_count = orders.size

      summary = {
        date_range: format_date_range(start_date, end_date),
        completed_orders: order_count,
        gross_receipts_including_tax: format_currency(gross_total),
        refunds: format_currency(refund_total),
        net_receipts_including_tax: format_currency(gross_total - refund_total),
        tax_on_sales_before_refunds: format_currency(orders.sum { |order| order.tax_total.to_d }),
        discounts: format_currency(orders.sum { |order| order.discount_total.to_d }),
        average_order: format_currency(order_count.positive? ? gross_total / order_count : 0)
      }
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
