# frozen_string_literal: true

module ReportTemplates
  class PaymentMethodBreakdown < ReportTemplate
    SALES_STATUSES = %i[completed partially_refunded refunded].freeze

    def self.key         = "payment_method_breakdown"
    def self.title       = "Payment method breakdown"
    def self.description = "Shows tender totals and transaction counts by payment method for completed sales in a date range."

    def self.parameters
      [
        { key: :start_date, type: :date, label: "Start date", required: false },
        { key: :end_date,   type: :date, label: "End date",   required: false }
      ]
    end

    def self.chart_type = "doughnut"

    def self.table_columns
      [
        { key: :payment_method, label: "Payment method" },
        { key: :payments,       label: "Payments" },
        { key: :orders,         label: "Orders" },
        { key: :total,          label: "Total" },
        { key: :average,        label: "Average payment" },
        { key: :share,          label: "Share" }
      ]
    end

    def self.generate(params)
      start_date, end_date = report_date_range(params)
      payments = fetch_payments(start_date, end_date)
      rows = build_rows(payments)

      {
        chart: {
          labels: rows.map { |row| row[:payment_method] },
          datasets: [ {
            label: "Payments",
            data: rows.map { |row| row[:total_amount] },
            backgroundColor: [
              "rgba(16, 185, 129, 0.75)",
              "rgba(59, 130, 246, 0.75)",
              "rgba(245, 158, 11, 0.75)",
              "rgba(139, 92, 246, 0.75)",
              "rgba(236, 72, 153, 0.75)",
              "rgba(100, 116, 139, 0.75)"
            ],
            borderWidth: 1
          } ]
        },
        table: rows.map { |row| row.except(:total_amount) },
        summary: build_summary(rows, payments, start_date, end_date)
      }
    end

    def self.fetch_payments(start_date, end_date)
      OrderPayment
        .joins(:order)
        .where(orders: { status: SALES_STATUSES, completed_at: start_date.beginning_of_day..end_date.end_of_day, discarded_at: nil })
        .includes(:order)
    end
    private_class_method :fetch_payments

    def self.build_rows(payments)
      total_amount = payments.sum { |payment| payment.amount.to_d }

      payments.group_by(&:payment_method).map do |method, method_payments|
        amount = method_payments.sum { |payment| payment.amount.to_d }
        count = method_payments.size
        {
          payment_method: method.to_s.humanize,
          payments: count,
          orders: method_payments.map(&:order_id).uniq.size,
          total_amount: amount,
          total: format_currency(amount),
          average: format_currency(count.positive? ? amount / count : 0),
          share: format_percentage(total_amount.positive? ? (amount / total_amount) * 100 : 0)
        }
      end.sort_by { |row| -row[:total_amount] }
    end
    private_class_method :build_rows

    def self.build_summary(rows, payments, start_date, end_date)
      total_collected = rows.sum { |row| row[:total_amount] }
      top_method = rows.first

      {
        date_range: format_date_range(start_date, end_date),
        total_collected: format_currency(total_collected),
        payment_count: payments.size,
        order_count: payments.map(&:order_id).uniq.size,
        average_payment: format_currency(payments.any? ? total_collected / payments.size : 0),
        top_payment_method: top_method ? "#{top_method[:payment_method]} (#{top_method[:share]})" : "None"
      }
    end
    private_class_method :build_summary

    register!
  end
end
