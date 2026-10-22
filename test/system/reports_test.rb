require "application_system_test_case"

class ReportsTest < ApplicationSystemTestCase
  setup { system_sign_in_as(users(:admin)) }

  test "find a report, choose dates, and automatically receive completed results" do
    visit reports_path
    assert_selector "h1", text: "Report library"
    fill_in "Find a report", with: "Sales summary"
    within ".report-catalog" do
      assert_selector "a", count: 1
      click_link "Sales summary"
    end
    assert_selector "h1", text: "Sales summary"
    click_button "Last month"
    assert_field "Start date", with: Date.current.prev_month.beginning_of_month.iso8601
    assert_field "End date", with: Date.current.prev_month.end_of_month.iso8601
    click_button "This month"
    click_button "Generate report"
    assert_text "Your report is queued"
    assert_no_link "Download Excel"
    report = Report.order(:id).last
    GenerateReportJob.perform_now(report.id)
    assert_link "Download Excel", wait: 10
    assert_selector "canvas", wait: 5
    assert_selector "h2", text: "Report details"
    click_link "Change settings / run again"
    assert_field "Start date", with: report.parameters["start_date"]
    assert_field "End date", with: report.parameters["end_date"]
  end

  test "custom export changes columns with the dataset and saves reusable settings" do
    visit new_report_path(template: "custom_export")
    select "Customers", from: "Data"
    assert_no_field "Start date"
    assert_text "One row per current customer"
    click_button "Clear selection"
    assert_button "Generate report", disabled: true
    check "Customer"
    check "Email"
    fill_in "Report name (optional)", with: "Customer mailing list"
    click_button "Generate report"
    assert_text "Your report is queued"
    report = Report.order(:id).last
    assert_equal "customers", report.parameters["dataset"]
    assert_equal %w[name email], report.parameters["columns"]
    GenerateReportJob.perform_now(report.id)
    assert_link "Download Excel", wait: 10
    within 'section[aria-label="Report details"]' do
      assert_selector "th", text: "Customer"
      assert_selector "th", text: "Email"
      assert_no_selector "th", text: "Phone"
      fill_in "Search these rows", with: customers(:acme_corp).email
      assert_selector "tbody tr", count: 1
    end
    click_link "Change settings / run again"
    assert_select "Data", selected: "Customers"
    assert_checked_field "Email"
    assert_unchecked_field "Phone"
  end

  test "staff can open and download snapshots without administrator actions" do
    system_sign_in_as(users(:one))
    visit reports_path
    assert_no_selector ".report-catalog"
    visit report_path(reports(:completed_report))
    assert_link "Download Excel"
    assert_no_link "Change settings / run again"
    assert_no_button "Delete saved report"
    assert_no_link "Generate report"
  end

  test "nested charts and held rows are visible" do
    report = reports(:completed_report)
    chart = report.result_data["chart"]
    report.update!(result_data: report.result_data.merge("chart" => { "discount_analysis" => chart, "order_counts" => chart }, "held_orders_table" => report.result_data["table"]))
    visit report_path(report)
    assert_selector "canvas", count: 2
    assert_selector "h2", text: "Held orders (excluded from totals)"
    assert_selector "summary", text: "View chart data", count: 2
  end

  test "library and custom export fit a narrow screen" do
    page.driver.browser.manage.window.resize_to(650, 900)
    visit reports_path
    assert_selector "h1", text: "Report library"
    assert page.evaluate_script("document.documentElement.scrollWidth <= window.innerWidth")
    visit new_report_path(template: "custom_export")
    assert_selector "h1", text: "Custom Excel export"
    assert page.evaluate_script("document.documentElement.scrollWidth <= window.innerWidth")
  ensure
    page.driver.browser.manage.window.resize_to(1400, 1400)
  end
end
