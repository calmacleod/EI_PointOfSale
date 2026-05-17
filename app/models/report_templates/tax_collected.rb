# frozen_string_literal: true

module ReportTemplates
  class TaxCollected < ReportTemplate
    SALES_STATUSES = %i[completed partially_refunded refunded].freeze

    def self.key         = "tax_collected"
    def self.title       = "Tax collected"
    def self.description = "Breaks completed sales down by tax code, taxable sales, exempt sales, and tax collected."

    def self.parameters
      [
        { key: :start_date, type: :date, label: "Start date", required: false },
        { key: :end_date,   type: :date, label: "End date",   required: false }
      ]
    end

    def self.chart_type = "bar"

    def self.table_columns
      [
        { key: :tax_code,      label: "Tax code" },
        { key: :rate,          label: "Rate" },
        { key: :line_count,    label: "Lines" },
        { key: :taxable_sales, label: "Taxable sales" },
        { key: :tax_collected, label: "Tax collected" }
      ]
    end

    def self.generate(params)
      start_date, end_date = report_date_range(params)
      rows = build_rows(fetch_lines(start_date, end_date))

      {
        chart: {
          labels: rows.map { |row| row[:tax_code] },
          datasets: [
            {
              label: "Tax collected",
              data: rows.map { |row| row[:tax_amount] },
              backgroundColor: "rgba(59, 130, 246, 0.65)",
              borderColor: "rgba(59, 130, 246, 1)",
              borderWidth: 1
            },
            {
              label: "Taxable sales",
              data: rows.map { |row| row[:taxable_amount] },
              backgroundColor: "rgba(16, 185, 129, 0.45)",
              borderColor: "rgba(16, 185, 129, 1)",
              borderWidth: 1
            }
          ]
        },
        table: rows.map { |row| row.except(:tax_amount, :taxable_amount) },
        summary: build_summary(rows, start_date, end_date)
      }
    end

    def self.fetch_lines(start_date, end_date)
      OrderLine
        .joins(:order)
        .merge(Order.kept.where(status: SALES_STATUSES, completed_at: start_date.beginning_of_day..end_date.end_of_day))
        .includes(:tax_code)
    end
    private_class_method :fetch_lines

    def self.build_rows(lines)
      lines.group_by { |line| [ line.tax_code&.code || "No tax code", line.tax_rate.to_d ] }
           .map do |(code, rate), tax_lines|
        taxable_sales = tax_lines.sum { |line| line.line_total.to_d - line.tax_amount.to_d }
        tax_collected = tax_lines.sum { |line| line.tax_amount.to_d }

        {
          tax_code: code,
          rate: format_percentage(rate * 100),
          line_count: tax_lines.size,
          taxable_amount: taxable_sales,
          taxable_sales: format_currency(taxable_sales),
          tax_amount: tax_collected,
          tax_collected: format_currency(tax_collected)
        }
      end.sort_by { |row| [ -row[:tax_amount], row[:tax_code] ] }
    end
    private_class_method :build_rows

    def self.build_summary(rows, start_date, end_date)
      {
        date_range: format_date_range(start_date, end_date),
        tax_codes: rows.size,
        taxable_sales: format_currency(rows.sum { |row| row[:taxable_amount] }),
        tax_collected: format_currency(rows.sum { |row| row[:tax_amount] }),
        highest_tax_code: rows.first ? "#{rows.first[:tax_code]} (#{rows.first[:tax_collected]})" : "None"
      }
    end
    private_class_method :build_summary

    register!
  end
end
