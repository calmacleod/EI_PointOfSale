# frozen_string_literal: true

require "test_helper"

class GenerateReportJobTest < ActiveJob::TestCase
  test "marks report as completed with result data" do
    report = reports(:pending_report)

    perform_enqueued_jobs do
      GenerateReportJob.perform_later(report.id)
    end

    report.reload
    assert_equal "completed", report.status
    assert report.result_data.present?
    assert report.started_at.present?
    assert report.completed_at.present?
    assert_nil report.error_message
  end

  test "result contains chart, table, and summary" do
    report = reports(:pending_report)

    perform_enqueued_jobs do
      GenerateReportJob.perform_later(report.id)
    end

    report.reload
    result = report.result_data.deep_symbolize_keys
    assert result[:chart].present?
    assert result[:table].is_a?(Array)
    assert result[:summary].is_a?(Hash)
  end

  test "marks report as failed on error" do
    report = reports(:pending_report)
    report.update!(report_type: "nonexistent_report_type")

    # The job re-raises after marking the report as failed, so we catch it here
    error = assert_raises(RuntimeError) do
      GenerateReportJob.perform_now(report.id)
    end

    assert_match(/Unknown report type/, error.message)
    report.reload
    assert_equal "failed", report.status
    assert report.error_message.present?
  end
end
