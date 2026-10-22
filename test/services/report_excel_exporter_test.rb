require "test_helper"
require "zip"

class ReportExcelExporterTest < ActiveSupport::TestCase
  test "Excel contains typed amounts and dates, text identifiers, filters, and a frozen header" do
    report = reports(:completed_report)
    report.result_data = {
      columns: [
        { key: "code", label: "Code" }, { key: "amount", label: "Amount", type: "currency" },
        { key: "count", label: "Count", type: "integer" }, { key: "rate", label: "Rate", type: "percentage" },
        { key: "date", label: "Date", type: "date" }, { key: "name", label: "Name" }
      ],
      table: [ { code: "0001234567890123456789", amount: "$12.34", count: 2, rate: "13.0%", date: "2026-10-01", name: '=HYPERLINK("https://example.com")' } ]
    }
    workbook = unzip(ReportExcelExporter.generate(report))
    sheet = xml(workbook, "xl/worksheets/sheet1.xml")
    assert_equal "inlineStr", sheet.at_xpath('//c[@r="A2"]')["t"]
    assert_equal "0001234567890123456789", sheet.at_xpath('//c[@r="A2"]//t').text
    assert_equal "12.34", sheet.at_xpath('//c[@r="B2"]/v').text
    assert_equal "2", sheet.at_xpath('//c[@r="C2"]/v').text
    assert_in_delta 0.13, sheet.at_xpath('//c[@r="D2"]/v').text.to_f
    assert sheet.at_xpath('//c[@r="E2"]/v'), "Dates must be numeric Excel dates"
    assert_empty sheet.xpath("//f"), "User-entered values must not become formulas"
    assert_includes sheet.at_xpath('//c[@r="F2"]//t').text, "HYPERLINK"
    assert_equal "frozen", sheet.at_xpath("//pane")["state"]
    assert_equal "A2", sheet.at_xpath("//pane")["topLeftCell"]
    assert_equal "A1:F2", xml(workbook, "xl/tables/table1.xml").at_xpath("//autoFilter")["ref"]
    assert_equal %w[Data Summary], xml(workbook, "xl/workbook.xml").xpath("//sheet").map { |node| node["name"] }
  end

  test "empty results still have Data headers and preserve the selected settings" do
    report = reports(:completed_report)
    report.result_data = { table: [], summary: { total_customers: 0 } }
    workbook = unzip(ReportExcelExporter.generate(report))
    assert_equal report.template.table_columns.size, xml(workbook, "xl/worksheets/sheet1.xml").xpath('//row[@r="1"]/c').size
    assert_includes workbook.fetch("xl/worksheets/sheet2.xml"), "2026-01-01"
  end

  test "legacy snapshots use declared column types without rerunning their query" do
    report = reports(:completed_report)
    workbook = unzip(ReportExcelExporter.generate(report))
    sheet = xml(workbook, "xl/worksheets/sheet1.xml")
    assert_equal "inlineStr", sheet.at_xpath('//c[@r="B2"]')["t"]
    assert sheet.at_xpath('//c[@r="E2"]/v')
  end

  test "held orders remain separate from completed sales" do
    report = reports(:completed_report)
    report.result_data["held_orders_table"] = report.result_data["table"]
    workbook = unzip(ReportExcelExporter.generate(report))
    assert_equal [ "Data", "Held orders", "Summary" ], xml(workbook, "xl/workbook.xml").xpath("//sheet").map { |node| node["name"] }
  end

  private

    def unzip(data)
      entries = {}
      Zip::File.open_buffer(data) { |zip| entries = zip.entries.to_h { |entry| [ entry.name, entry.get_input_stream.read ] } }
      entries
    end

    def xml(workbook, path)
      Nokogiri::XML(workbook.fetch(path)).remove_namespaces!
    end
end
