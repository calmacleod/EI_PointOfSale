# frozen_string_literal: true

module ReportTemplates
  class NewCustomersByDate < ReportTemplate
    def self.key         = "new_customers_by_date"
    def self.title       = "New customers by date"
    def self.description = "Shows new customer registrations over a date range, with a daily breakdown chart and full customer list."

    def self.parameters
      [
        { key: :start_date, type: :date, label: "Start date", required: true },
        { key: :end_date,   type: :date, label: "End date",   required: true }
      ]
    end

    def self.chart_type = "bar"

    def self.table_columns
      [
        { key: :name,          label: "Name" },
        { key: :member_number, label: "Member #" },
        { key: :email,         label: "Email" },
        { key: :phone,         label: "Phone" },
        { key: :registered_on, label: "Registered on" }
      ]
    end

    def self.generate(params)
      start_date = Date.parse(params[:start_date].to_s)
      end_date   = Date.parse(params[:end_date].to_s)
      date_range = start_date.beginning_of_day..end_date.end_of_day

      # Daily registration counts
      daily_counts = Customer.kept
        .where(created_at: date_range)
        .group(Arel.sql("DATE(created_at)"))
        .order(Arel.sql("DATE(created_at)"))
        .count

      # Fill in zero-count days so the chart has no gaps
      all_dates = (start_date..end_date).map(&:to_s)
      counts    = all_dates.map { |d| daily_counts[Date.parse(d)] || daily_counts[d] || 0 }

      # Detailed customer records for the table
      customers = Customer.kept
        .where(created_at: date_range)
        .order(:created_at)

      table_data = customers.map do |customer|
        {
          name:          customer.name,
          member_number: customer.member_number,
          email:         customer.email,
          phone:         customer.phone,
          registered_on: customer.created_at.to_date.to_s
        }
      end

      {
        chart: {
          labels: all_dates,
          datasets: [
            {
              label: "New customers",
              data: counts,
              backgroundColor: "rgba(59, 130, 246, 0.6)",
              borderColor: "rgba(59, 130, 246, 1)",
              borderWidth: 1
            }
          ]
        },
        table: table_data,
        summary: {
          total_customers: table_data.size,
          date_range: "#{start_date.strftime('%b %d, %Y')} – #{end_date.strftime('%b %d, %Y')}",
          busiest_day: all_dates[counts.index(counts.max)],
          busiest_day_count: counts.max
        }
      }
    end

    register!
  end
end
