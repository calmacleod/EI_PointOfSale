# frozen_string_literal: true

class GenerateReportJob < ApplicationJob
  queue_as :default

  def perform(report_id)
    report = Report.find(report_id)
    report.update!(status: "processing", started_at: Time.current)

    template = ReportTemplate.find(report.report_type)
    raise "Unknown report type: #{report.report_type}" unless template

    result = template.generate(report.parameters.symbolize_keys)
    report.update!(status: "completed", result_data: result, completed_at: Time.current)
  rescue StandardError => e
    report&.update!(status: "failed", error_message: e.message, completed_at: Time.current)
    raise
  end
end
