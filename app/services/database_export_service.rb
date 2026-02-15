# frozen_string_literal: true

require "caxlsx"

# Generates an Excel (.xlsx) export of the application's business data.
# Each table gets its own worksheet with column headers and all rows.
#
# Sensitive columns (like password_digest) and internal infrastructure tables
# (Solid Queue, Active Storage, sessions, etc.) are excluded.
#
# Usage:
#   xlsx_data = DatabaseExportService.generate
#   # => String (binary xlsx content)
#
class DatabaseExportService
  # Tables to export (order they appear as sheets)
  EXPORT_TABLES = %w[
    users
    customers
    products
    product_variants
    services
    categories
    categorizations
    suppliers
    tax_codes
    stores
  ].freeze

  # Columns to exclude from all tables (sensitive or internal)
  EXCLUDED_COLUMNS = %w[
    password_digest
  ].freeze

  class << self
    # Generates the Excel workbook and returns the binary content.
    #
    # @return [String] binary .xlsx content suitable for send_data
    def generate
      package = Axlsx::Package.new
      workbook = package.workbook

      header_style = workbook.styles.add_style(
        b: true,
        bg_color: "4472C4",
        fg_color: "FFFFFF",
        sz: 11,
        border: { style: :thin, color: "000000" }
      )

      date_style = workbook.styles.add_style(
        format_code: "yyyy-mm-dd hh:mm:ss",
        sz: 10
      )

      body_style = workbook.styles.add_style(sz: 10)

      EXPORT_TABLES.each do |table_name|
        add_sheet(workbook, table_name, header_style: header_style, body_style: body_style, date_style: date_style)
      end

      package.to_stream.read
    end

    private

      def add_sheet(workbook, table_name, header_style:, body_style:, date_style:)
        model = model_for_table(table_name)
        return unless model

        columns = model.column_names - EXCLUDED_COLUMNS
        return if columns.empty?

        sheet_name = table_name.titleize.truncate(31) # Excel sheet names max 31 chars

        workbook.add_worksheet(name: sheet_name) do |sheet|
          # Header row
          sheet.add_row columns.map(&:titleize), style: header_style

          # Data rows
          model.find_each do |record|
            values = columns.map { |col| format_value(record.read_attribute(col)) }
            styles = columns.map { |col| timestamp_column?(col) ? date_style : body_style }
            sheet.add_row values, style: styles, types: columns.map { |col| column_type(col) }
          end

          # Auto-width columns (estimate based on header length, capped)
          sheet.column_widths(*columns.map { |col| [ col.length + 4, 40 ].min })
        end
      end

      def model_for_table(table_name)
        table_name.classify.constantize
      rescue NameError
        nil
      end

      def format_value(value)
        case value
        when Time, DateTime, ActiveSupport::TimeWithZone
          value
        when Date
          value.to_s
        when BigDecimal
          value.to_f
        when Array
          value.join(", ")
        when Hash
          value.to_json
        else
          value
        end
      end

      def timestamp_column?(column_name)
        column_name.end_with?("_at", "_date") || column_name.in?(%w[created_at updated_at discarded_at computed_at])
      end

      def column_type(column_name)
        return :date if timestamp_column?(column_name)

        :string
      end
  end
end
