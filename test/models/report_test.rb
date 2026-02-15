# frozen_string_literal: true

require "test_helper"

class ReportTest < ActiveSupport::TestCase
  test "valid report with required attributes" do
    report = Report.new(
      report_type: "new_customers_by_date",
      title: "Test report",
      generated_by: users(:admin)
    )
    assert report.valid?
    assert_equal "pending", report.status
  end

  test "requires report_type" do
    report = Report.new(title: "Test", generated_by: users(:admin))
    assert_not report.valid?
    assert_includes report.errors[:report_type], "can't be blank"
  end

  test "requires title" do
    report = Report.new(report_type: "new_customers_by_date", generated_by: users(:admin))
    assert_not report.valid?
    assert_includes report.errors[:title], "can't be blank"
  end

  test "status must be valid" do
    report = Report.new(
      report_type: "new_customers_by_date",
      title: "Test",
      status: "invalid",
      generated_by: users(:admin)
    )
    assert_not report.valid?
    assert_includes report.errors[:status], "is not included in the list"
  end

  test "status query methods" do
    assert reports(:pending_report).pending?
    assert reports(:completed_report).completed?
    assert reports(:failed_report).failed?
  end

  test "template returns the matching ReportTemplate" do
    report = reports(:completed_report)
    assert_equal ReportTemplates::NewCustomersByDate, report.template
  end

  test "duration returns elapsed time for completed reports" do
    report = reports(:completed_report)
    report.update!(started_at: 10.seconds.ago, completed_at: Time.current)
    assert_in_delta 10.0, report.duration, 1.0
  end

  test "duration returns nil when timestamps are missing" do
    report = reports(:pending_report)
    assert_nil report.duration
  end

  test "recent scope orders by created_at desc" do
    reports = Report.recent
    assert reports.first.created_at >= reports.last.created_at
  end
end
