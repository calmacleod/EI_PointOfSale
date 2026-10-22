# frozen_string_literal: true

# Base class for report templates. Each template defines how to generate
# a specific type of report — its parameters, query logic, chart configuration,
# and table columns.
#
# To add a new report type:
#   1. Create a subclass in app/models/report_templates/
#   2. Implement the required class methods (key, title, description, etc.)
#   3. Call `register!` at the bottom of the file
#
# Example:
#   class ReportTemplates::MyReport < ReportTemplate
#     def self.key         = "my_report"
#     def self.title       = "My Report"
#     def self.description = "Describes what this report shows"
#     def self.parameters  = [{ key: :start_date, type: :date, label: "Start", required: true }]
#     def self.generate(params) = { chart: ..., table: ..., summary: ... }
#     def self.chart_type  = "bar"
#     def self.table_columns = [{ key: :name, label: "Name" }]
#     register!
#   end
#
class ReportTemplate
  class << self
    # ── Registry ───────────────────────────────────────────────────────
    def registry
      @registry ||= {}
    end

    def register(key, klass)
      registry[key.to_s] = klass
    end

    def all
      load_templates!
      registry.values
    end

    def find(key)
      load_templates! unless @templates_loaded
      registry[key.to_s]
    end

    # Convenience for subclasses: call `register!` at the end of the class body.
    def register!
      ReportTemplate.register(key, self)
    end

    # ── Template discovery ──────────────────────────────────────────────

    # Eagerly loads all template classes from app/models/report_templates/
    # so they can self-register. Safe to call multiple times.
    def load_templates!
      return if @templates_loaded

      Dir[Rails.root.join("app/models/report_templates/*.rb")].each do |file|
        class_name = "ReportTemplates::#{File.basename(file, '.rb').camelize}"
        class_name.constantize
      rescue NameError => e
        Rails.logger.warn { "[ReportTemplate] Could not load #{class_name}: #{e.message}" }
      end
      @templates_loaded = true
    end

    # ── Interface (override in subclasses) ─────────────────────────────
    def key         = raise(NotImplementedError)
    def title       = raise(NotImplementedError)
    def description = raise(NotImplementedError)

    # Array of parameter definitions:
    #   [{ key: :start_date, type: :date, label: "Start date", required: true }]
    # Supported types: :date, :string, :integer, :select
    def parameters = raise(NotImplementedError)

    # Executes the report query and returns structured result data:
    #   { chart: { labels: [...], datasets: [...] }, table: [...], summary: { ... } }
    def generate(_params)
      raise NotImplementedError
    end

    # Chart.js chart type: "bar", "line", "pie", "doughnut", etc.
    def chart_type = "bar"

    # Table column definitions for displaying results:
    #   [{ key: :name, label: "Name" }, ...]
    def table_columns = raise(NotImplementedError)

    def category
      case key
      when "out_of_stock_products", "inventory_valuation" then "Inventory"
      when "customer_sales", "new_customers_by_date" then "Customers"
      when "custom_export" then "Excel workspace"
      else "Sales"
      end
    end

    def output_columns(_params = {}) = table_columns

    # Resolve defaults before enqueueing so a report run after midnight still
    # uses the dates the user saw. Only declared parameters reach a template.
    def default_parameters
      parameters.to_h do |parameter|
        value = case parameter[:key].to_s
        when "start_date" then Date.current.beginning_of_month.iso8601
        when "end_date" then Date.current.iso8601
        else parameter[:default] || parameter[:options]&.first&.last || ""
        end
        [ parameter[:key].to_s, value ]
      end
    end

    def normalize_parameters(values)
      supplied = values.to_h.stringify_keys.slice(*parameters.map { |parameter| parameter[:key].to_s })
      default_parameters.merge(supplied) { |_key, default, value| value == "" ? default : value }
    end

    def parameter_errors(values)
      values = values.to_h.stringify_keys
      errors = []
      dates = {}
      parameters.each do |parameter|
        value = values[parameter[:key].to_s]
        if parameter[:type] == :date
          begin
            raise ArgumentError unless value.is_a?(String) && value.match?(/\A\d{4}-\d{2}-\d{2}\z/)
            dates[parameter[:key]] = Date.iso8601(value)
          rescue ArgumentError
            errors << "#{parameter[:label]} must be a valid date."
          end
        elsif parameter[:type] == :select
          errors << "Choose a valid #{parameter[:label].downcase}." unless parameter[:options].any? { |option| option.last == value }
        elsif parameter[:required] && value.blank?
          errors << "#{parameter[:label]} is required."
        end
      end
      if dates[:start_date] && dates[:end_date] && dates[:end_date] < dates[:start_date]
        errors << "End date must be on or after start date."
      end
      if dates[:start_date] && dates[:end_date] && dates[:end_date] - dates[:start_date] > 3660
        errors << "Choose a date range of ten years or less."
      end
      errors
    end

    private

      def parse_report_date(value, default)
        return default if value.blank?

        Date.parse(value.to_s)
      rescue ArgumentError
        default
      end

      def report_date_range(params, default_start: 30.days.ago.to_date, default_end: Date.current)
        start_date = parse_report_date(params[:start_date], default_start)
        end_date = parse_report_date(params[:end_date], default_end)

        [ start_date, end_date ]
      end

      def format_currency(amount)
        amount = amount.to_d
        "$#{format('%.2f', amount)}"
      end

      def format_percentage(amount)
        "#{format('%.1f', amount.to_d)}%"
      end

      def format_date_range(start_date, end_date)
        "#{start_date.strftime('%b %d, %Y')} - #{end_date.strftime('%b %d, %Y')}"
      end
  end
end
