# frozen_string_literal: true

module ReportTemplates
  class CustomerSales < ReportTemplate
    TABLE_LIMIT = 500
    SALES_STATUSES = %i[completed partially_refunded refunded].freeze

    def self.key         = "customer_sales"
    def self.title       = "Customer sales"
    def self.description = "Ranks customers by completed order count and net spend, including quick-sale activity."

    def self.parameters
      [
        { key: :start_date, type: :date, label: "Start date", required: false },
        { key: :end_date,   type: :date, label: "End date",   required: false },
        {
          key: :include_quick_sales,
          type: :select,
          label: "Quick sales",
          required: false,
          options: [
            [ "Include quick sales", "1" ],
            [ "Customers only", "0" ]
          ]
        }
      ]
    end

    def self.chart_type = "bar"

    def self.table_columns
      [
        { key: :rank,          label: "#" },
        { key: :customer,      label: "Customer" },
        { key: :member_number, label: "Member #" },
        { key: :orders,        label: "Orders" },
        { key: :gross_sales,   label: "Gross sales" },
        { key: :refunds,       label: "Refunds" },
        { key: :net_sales,     label: "Net sales" },
        { key: :average_order, label: "Avg order" },
        { key: :last_purchase, label: "Last purchase" }
      ]
    end

    def self.generate(params)
      start_date, end_date = report_date_range(params)
      include_quick_sales = params[:include_quick_sales] != "0"
      orders = fetch_orders(start_date, end_date, include_quick_sales)
      refund_totals_by_order_id = Refund.where(order_id: orders.map(&:id)).group(:order_id).sum(:total)
      rows = build_rows(orders, refund_totals_by_order_id)
      chart_rows = rows.first(10)

      {
        chart: {
          labels: chart_rows.map { |row| row[:customer] },
          datasets: [ {
            label: "Net sales",
            data: chart_rows.map { |row| row[:net_amount] },
            backgroundColor: "rgba(16, 185, 129, 0.65)",
            borderColor: "rgba(16, 185, 129, 1)",
            borderWidth: 1
          } ]
        },
        table: rows.first(TABLE_LIMIT).map { |row| row.except(:net_amount, :gross_amount, :refund_amount) },
        summary: build_summary(rows, start_date, end_date)
      }
    end

    def self.fetch_orders(start_date, end_date, include_quick_sales)
      scope = Order.kept
        .where(status: SALES_STATUSES)
        .where(completed_at: start_date.beginning_of_day..end_date.end_of_day)
        .includes(:customer)

      scope = scope.where.not(customer_id: nil) unless include_quick_sales
      scope
    end
    private_class_method :fetch_orders

    def self.build_rows(orders, refund_totals_by_order_id)
      grouped = orders.group_by(&:customer_id)

      grouped.map do |_customer_id, customer_orders|
        customer = customer_orders.first.customer
        gross = customer_orders.sum { |order| order.total.to_d }
        refunds = customer_orders.sum { |order| refund_totals_by_order_id[order.id].to_d }
        net = gross - refunds
        order_count = customer_orders.size

        {
          customer: customer&.name || "Quick Sale",
          member_number: customer&.member_number,
          orders: order_count,
          gross_amount: gross,
          gross_sales: format_currency(gross),
          refund_amount: refunds,
          refunds: format_currency(refunds),
          net_amount: net,
          net_sales: format_currency(net),
          average_order: format_currency(order_count.positive? ? net / order_count : 0),
          last_purchase: customer_orders.map(&:completed_at).compact.max&.strftime("%b %d, %Y")
        }
      end.sort_by { |row| [ -row[:net_amount], -row[:orders], row[:customer] ] }
             .each_with_index
             .map { |row, index| row.merge(rank: index + 1) }
    end
    private_class_method :build_rows

    def self.build_summary(rows, start_date, end_date)
      net_sales = rows.sum { |row| row[:net_amount] }
      total_orders = rows.sum { |row| row[:orders] }

      summary = {
        date_range: format_date_range(start_date, end_date),
        customers: rows.count { |row| row[:customer] != "Quick Sale" },
        quick_sale_orders: rows.find { |row| row[:customer] == "Quick Sale" }&.dig(:orders).to_i,
        repeat_customers: rows.count { |row| row[:customer] != "Quick Sale" && row[:orders] > 1 },
        net_sales: format_currency(net_sales),
        average_per_customer: format_currency(rows.any? ? net_sales / rows.size : 0),
        average_order: format_currency(total_orders.positive? ? net_sales / total_orders : 0),
        top_customer: rows.first ? "#{rows.first[:customer]} (#{rows.first[:net_sales]})" : "None"
      }
      summary[:table_note] = "Showing first #{TABLE_LIMIT} of #{rows.size} customers" if rows.size > TABLE_LIMIT
      summary
    end
    private_class_method :build_summary

    register!
  end
end
