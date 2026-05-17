# frozen_string_literal: true

module ReportTemplates
  class TopSellingItems < ReportTemplate
    TABLE_LIMIT = 100
    SALES_STATUSES = %i[completed partially_refunded refunded].freeze

    def self.key         = "top_selling_items"
    def self.title       = "Top selling items"
    def self.description = "Ranks products and services by quantity sold and net sales for completed orders in a date range."

    def self.parameters
      [
        { key: :start_date, type: :date, label: "Start date", required: false },
        { key: :end_date,   type: :date, label: "End date",   required: false },
        {
          key: :item_type,
          type: :select,
          label: "Items",
          required: false,
          options: [
            [ "Products and services", "" ],
            [ "Products only", "Product" ],
            [ "Services only", "Service" ],
            [ "Gift certificates only", "GiftCertificate" ]
          ]
        }
      ]
    end

    def self.chart_type = "bar"

    def self.table_columns
      [
        { key: :rank,          label: "#" },
        { key: :code,          label: "Code" },
        { key: :name,          label: "Item" },
        { key: :item_type,     label: "Type" },
        { key: :quantity_sold, label: "Qty sold" },
        { key: :net_sales,     label: "Net sales" },
        { key: :tax,           label: "Tax" },
        { key: :average_price, label: "Avg price" }
      ]
    end

    def self.generate(params)
      start_date, end_date = report_date_range(params)
      lines = fetch_lines(start_date, end_date, params[:item_type].presence)
      rows = build_rows(lines)
      chart_rows = rows.first(10)

      {
        chart: {
          labels: chart_rows.map { |row| row[:name] },
          datasets: [ {
            label: "Net sales",
            data: chart_rows.map { |row| row[:net_sales_amount] },
            backgroundColor: "rgba(59, 130, 246, 0.65)",
            borderColor: "rgba(59, 130, 246, 1)",
            borderWidth: 1
          } ]
        },
        table: rows.first(TABLE_LIMIT).map { |row| row.except(:net_sales_amount, :tax_amount, :quantity_amount) },
        summary: build_summary(rows, start_date, end_date)
      }
    end

    def self.fetch_lines(start_date, end_date, item_type)
      scope = OrderLine
        .joins(:order)
        .merge(Order.kept.where(status: SALES_STATUSES, completed_at: start_date.beginning_of_day..end_date.end_of_day))

      scope = scope.where(sellable_type: item_type) if item_type.present?
      scope
    end
    private_class_method :fetch_lines

    def self.build_rows(lines)
      grouped = lines.group_by { |line| [ line.sellable_type, line.sellable_id, line.code, line.name ] }

      grouped.map do |(sellable_type, _sellable_id, code, name), item_lines|
        quantity = item_lines.sum(&:quantity)
        net_sales = item_lines.sum { |line| line.line_total.to_d - line.tax_amount.to_d }
        tax = item_lines.sum { |line| line.tax_amount.to_d }

        {
          code: code,
          name: name,
          item_type: sellable_type.underscore.humanize,
          quantity_amount: quantity,
          quantity_sold: quantity,
          net_sales_amount: net_sales,
          net_sales: format_currency(net_sales),
          tax_amount: tax,
          tax: format_currency(tax),
          average_price: format_currency(quantity.positive? ? net_sales / quantity : 0)
        }
      end.sort_by { |row| [ -row[:net_sales_amount], -row[:quantity_amount], row[:name].to_s ] }
             .each_with_index
             .map { |row, index| row.merge(rank: index + 1) }
    end
    private_class_method :build_rows

    def self.build_summary(rows, start_date, end_date)
      net_sales = rows.sum { |row| row[:net_sales_amount] }
      quantity = rows.sum { |row| row[:quantity_amount] }
      top_item = rows.first

      summary = {
        date_range: format_date_range(start_date, end_date),
        unique_items_sold: rows.size,
        total_quantity_sold: quantity,
        net_sales: format_currency(net_sales),
        tax: format_currency(rows.sum { |row| row[:tax_amount] }),
        top_item: top_item ? "#{top_item[:name]} (#{top_item[:net_sales]})" : "None"
      }
      summary[:table_note] = "Showing first #{TABLE_LIMIT} of #{rows.size} items" if rows.size > TABLE_LIMIT
      summary
    end
    private_class_method :build_summary

    register!
  end
end
