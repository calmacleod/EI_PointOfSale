# frozen_string_literal: true

require "test_helper"

class ReportsControllerTest < ActionDispatch::IntegrationTest
  # ── Admin tests ─────────────────────────────────────────────────────

  setup do
    sign_in_as(users(:admin))
  end

  # ── Index ──────────────────────────────────────────────────────────

  test "admin: index renders available templates and past reports" do
    get reports_path
    assert_response :success
    assert_includes response.body, "New customers by date"
    assert_includes response.body, reports(:completed_report).title
  end

  # ── New ────────────────────────────────────────────────────────────

  test "admin: new renders parameter form for valid template" do
    get new_report_path(template: "new_customers_by_date")
    assert_response :success
    assert_includes response.body, "Start date"
    assert_includes response.body, "End date"
  end

  test "admin: new redirects for unknown template" do
    get new_report_path(template: "nonexistent")
    assert_redirected_to reports_path
  end

  # ── Create ─────────────────────────────────────────────────────────

  test "admin: create enqueues a report job and redirects to show" do
    assert_difference "Report.count", 1 do
      assert_enqueued_with(job: GenerateReportJob) do
        post reports_path, params: {
          report: {
            report_type: "new_customers_by_date",
            parameters: { start_date: "2026-01-01", end_date: "2026-01-31" }
          }
        }
      end
    end

    report = Report.last
    assert_redirected_to report_path(report)
    assert_equal "pending", report.status
    assert_equal "new_customers_by_date", report.report_type
    assert_equal users(:admin).id, report.generated_by_id
  end

  test "admin: create rejects unknown report type" do
    assert_no_difference "Report.count" do
      post reports_path, params: {
        report: { report_type: "nonexistent" }
      }
    end
    assert_redirected_to reports_path
  end

  # ── Show ───────────────────────────────────────────────────────────

  test "admin: show renders completed report with chart and table" do
    get report_path(reports(:completed_report))
    assert_response :success
    assert_includes response.body, "Chart"
    assert_includes response.body, "Details"
    assert_includes response.body, "PDF"
    assert_includes response.body, "Excel"
  end

  test "admin: show renders pending report with processing indicator" do
    get report_path(reports(:pending_report))
    assert_response :success
    assert_includes response.body, "queued for generation"
  end

  test "admin: show renders failed report with error" do
    get report_path(reports(:failed_report))
    assert_response :success
    assert_includes response.body, "generation failed"
    assert_includes response.body, "Something went wrong"
  end

  # ── Export PDF ─────────────────────────────────────────────────────

  test "admin: export_pdf downloads a PDF for completed report" do
    ReportChartRenderer.stub(:render, DUMMY_PNG) do
      get export_pdf_report_path(reports(:completed_report))
    end
    assert_response :success
    assert_equal "application/pdf", response.content_type
    assert_match(/attachment/, response.headers["Content-Disposition"])
  end

  test "admin: export_pdf redirects for non-completed report" do
    get export_pdf_report_path(reports(:pending_report))
    assert_redirected_to report_path(reports(:pending_report))
  end

  # ── Export Excel ───────────────────────────────────────────────────

  test "admin: export_excel downloads an xlsx for completed report" do
    get export_excel_report_path(reports(:completed_report))
    assert_response :success
    assert_equal "application/vnd.openxmlformats-officedocument.spreadsheetml.sheet", response.content_type
    assert_match(/attachment/, response.headers["Content-Disposition"])
  end

  test "admin: export_excel redirects for non-completed report" do
    get export_excel_report_path(reports(:pending_report))
    assert_redirected_to report_path(reports(:pending_report))
  end

  # ── Destroy ────────────────────────────────────────────────────────

  test "admin: destroy deletes the report" do
    assert_difference "Report.count", -1 do
      delete report_path(reports(:completed_report))
    end
    assert_redirected_to reports_path
  end

  # ── Common user access ─────────────────────────────────────────────

  test "common user: can view reports index" do
    sign_in_as(users(:one))
    get reports_path
    assert_response :success
  end

  test "common user: can view a report" do
    sign_in_as(users(:one))
    get report_path(reports(:completed_report))
    assert_response :success
  end

  test "common user: can export PDF" do
    sign_in_as(users(:one))
    ReportChartRenderer.stub(:render, DUMMY_PNG) do
      get export_pdf_report_path(reports(:completed_report))
    end
    assert_response :success
    assert_equal "application/pdf", response.content_type
  end

  test "common user: can export Excel" do
    sign_in_as(users(:one))
    get export_excel_report_path(reports(:completed_report))
    assert_response :success
    assert_equal "application/vnd.openxmlformats-officedocument.spreadsheetml.sheet", response.content_type
  end

  test "common user: cannot create reports" do
    sign_in_as(users(:one))
    assert_no_difference "Report.count" do
      post reports_path, params: {
        report: {
          report_type: "new_customers_by_date",
          parameters: { start_date: "2026-01-01", end_date: "2026-01-31" }
        }
      }
    end
    assert_redirected_to root_path
  end

  test "common user: cannot access new report form" do
    sign_in_as(users(:one))
    get new_report_path(template: "new_customers_by_date")
    assert_redirected_to root_path
  end

  test "common user: cannot delete reports" do
    sign_in_as(users(:one))
    assert_no_difference "Report.count" do
      delete report_path(reports(:completed_report))
    end
    assert_redirected_to root_path
  end
end
