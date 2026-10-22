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
    assert_includes inertia_props["templates"].map { |template| template["title"] }, "New customers by date"
    assert_includes inertia_props["rows"].map { |row| row["label"] }, reports(:completed_report).title
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

  test "admin: invalid dates and choices are shown without enqueueing a report" do
    [
      { start_date: "2026-02-30", end_date: "2026-03-01" },
      { start_date: "2026-10-22", end_date: "2026-01-01" },
      { start_date: "0001-01-01", end_date: "9999-12-31" }
    ].each do |parameters|
      assert_no_difference "Report.count" do
        assert_no_enqueued_jobs only: GenerateReportJob do
          post reports_path, params: { report: { report_type: "sales_summary", parameters: parameters } }
        end
      end
      assert_response :unprocessable_entity
      assert inertia_props.dig("form", "errors").any?
      assert_equal parameters[:start_date], inertia_props.dig("form", "values", "start_date")
    end
  end

  test "admin: defaults match the displayed dates and custom exports can be named" do
    get new_report_path(template: "sales_summary")
    shown = inertia_props.dig("form", "values")
    post reports_path, params: { report: { report_type: "sales_summary" } }
    assert_equal shown, Report.last.parameters

    post reports_path, params: { report: { report_type: "custom_export", title: "Mailing list", parameters: { dataset: "customers", columns: %w[name email] } } }
    report = Report.last
    assert_redirected_to report_path(report)
    assert_equal "Mailing list", report.title
    assert_equal %w[name email], report.parameters["columns"]
    queries = capture_sql_queries { get new_report_path(template: "custom_export", source: report.id) }
    refute queries.any? { |sql| sql.include?('FROM "reports"') && sql.match?(/result_data|"reports"\.\*/) }
    assert_equal report.parameters, inertia_props.dig("form", "values")
  end

  test "admin: custom export rejects undeclared columns and dataset" do
    assert_no_difference "Report.count" do
      post reports_path, params: { report: { report_type: "custom_export", parameters: { dataset: "users", columns: %w[password_digest] } } }
    end
    assert_response :unprocessable_entity
    assert inertia_props.dig("form", "errors").any?
  end

  # ── Show ───────────────────────────────────────────────────────────

  test "admin: show renders completed report with chart and table" do
    get report_path(reports(:completed_report))
    assert_response :success
    assert_equal "report_show", inertia_props["view"]
    assert_inertia_deferred_props "report.result_data", group: :report_data
    refute inertia_props.dig("report").key?("result_data")
    assert inertia_props.dig("actions", "pdf").present?
    assert inertia_props.dig("actions", "excel").present?

    inertia_load_deferred_props(:report_data)

    assert inertia.props.dig(:report, :result_data, :chart).present?
    assert inertia.props.dig(:report, :result_data, :table).present?
  end

  test "admin: show renders pending report with processing indicator" do
    get report_path(reports(:pending_report))
    assert_response :success
    assert_equal "pending", inertia_props.dig("report", "status")
    assert_nil inertia_props.dig("actions", "excel")
    assert_nil inertia_props.dig("actions", "pdf")
  end

  test "show does not fetch the saved dataset before the deferred request" do
    report = reports(:completed_report)
    queries = capture_sql_queries { get report_path(report) }
    reads = queries.select { |sql| sql.include?('FROM "reports"') }
    assert_equal 1, reads.size
    refute_match(/result_data|"reports"\.\*/, reads.first)
  end

  test "admin: show renders failed report with error" do
    get report_path(reports(:failed_report))
    assert_response :success
    assert_equal "failed", inertia_props.dig("report", "status")
    assert_equal "Something went wrong", inertia_props.dig("report", "error_message")
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

  test "admin: every custom dataset exports both Excel and PDF" do
    ReportTemplates::CustomExport::DATASETS.each_key do |dataset|
      report = Report.create!(report_type: "custom_export", title: "Custom #{dataset}", generated_by: users(:admin), parameters: { dataset: dataset })
      GenerateReportJob.perform_now(report.id)
      get export_excel_report_path(report)
      assert_response :success
      assert response.body.start_with?("PK")
      get export_pdf_report_path(report)
      assert_response :success
      assert response.body.start_with?("%PDF")
    end
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
    assert_nil inertia_props.dig("actions", "delete")
    assert_nil inertia_props.dig("actions", "rerun")
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
