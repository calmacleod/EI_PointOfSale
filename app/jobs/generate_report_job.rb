# frozen_string_literal: true

class GenerateReportJob < ApplicationJob
  queue_as :default

  def perform(report_id)
    report = Report.find_by(id: report_id)
    return unless report
    return if report.completed?

    begin
      report.update!(status: "processing", started_at: Time.current, completed_at: nil, error_message: nil)

      template = ReportTemplate.find(report.report_type)
      raise "Unknown report type: #{report.report_type}" unless template

      # Resolve old queued reports that predate explicit parameter defaults too.
      resolved_parameters = template.normalize_parameters(report.parameters)
      errors = template.parameter_errors(resolved_parameters)
      raise ArgumentError, errors.join(" ") if errors.any?

      report.update!(parameters: resolved_parameters)
      parameters = resolved_parameters.symbolize_keys
      result = template.generate(parameters)
      result[:columns] = template.output_columns(parameters)
      report.update!(status: "completed", result_data: result, completed_at: Time.current)
    rescue StandardError => e
      report.update!(status: "failed", error_message: e.message, completed_at: Time.current)
      raise
    end

    NotifyService.call(
      user: report.generated_by,
      title: "Report ready",
      body: "#{report.title} has finished generating.",
      category: "report",
      url: Rails.application.routes.url_helpers.report_path(report),
      persistent: true
    )
  end
end
