# frozen_string_literal: true

module ReportsHelper
  def render_report_status_badge(report)
    variant = case report.status
    when "completed"  then :success
    when "processing" then :info
    when "pending"    then :warning
    when "failed"     then :error
    else :neutral
    end

    status_chip(report.status.capitalize, variant)
  end
end
