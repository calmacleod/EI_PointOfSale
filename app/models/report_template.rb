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
      load_templates! if registry.empty?
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
  end
end
