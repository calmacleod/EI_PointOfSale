# frozen_string_literal: true

require "test_helper"
require "caxlsx"
require "zip"

class DatabaseExportServiceTest < ActiveSupport::TestCase
  test "generate returns valid xlsx binary data" do
    data = DatabaseExportService.generate

    assert data.present?
    assert_kind_of String, data
    # XLSX files start with the PK zip signature
    assert data.start_with?("PK"), "Expected xlsx (zip) file signature"
  end

  test "generate creates one sheet per exported table" do
    data = DatabaseExportService.generate
    sheet_names = extract_sheet_names(data)

    DatabaseExportService::EXPORT_TABLES.each do |table_name|
      expected = table_name.titleize.truncate(31)
      assert_includes sheet_names, expected, "Missing sheet: #{expected}"
    end
  end

  test "users sheet excludes password_digest column" do
    data = DatabaseExportService.generate
    headers = extract_first_row_values(data, "xl/worksheets/sheet1.xml")

    assert_includes headers, "Email Address", "Expected Email Address column header"
    assert_not_includes headers, "Password Digest", "password_digest should be excluded"
  end

  test "xlsx contains worksheet files for each table" do
    data = DatabaseExportService.generate
    filenames = extract_zip_filenames(data)

    # Should have at least as many sheet files as exported tables
    sheet_files = filenames.select { |f| f.start_with?("xl/worksheets/sheet") }
    assert sheet_files.size >= DatabaseExportService::EXPORT_TABLES.size,
      "Expected at least #{DatabaseExportService::EXPORT_TABLES.size} sheets, got #{sheet_files.size}"
  end

  test "does not include internal tables as sheets" do
    data = DatabaseExportService.generate
    sheet_names = extract_sheet_names(data)

    assert_not_includes sheet_names, "Sessions"
    assert_not_includes sheet_names, "Audits"
    assert_not_includes sheet_names, "Pg Search Documents"
  end

  private

    def extract_sheet_names(data)
      workbook_xml = read_zip_entry(data, "xl/workbook.xml")
      workbook_xml.scan(/<sheet[^>]+name="([^"]+)"/).flatten
    end

    # Extracts inline string values from the first row of a worksheet.
    # caxlsx uses inline strings (<is><t>value</t></is>) rather than shared strings.
    def extract_first_row_values(data, sheet_path)
      xml = read_zip_entry(data, sheet_path)
      return [] unless xml

      first_row = xml[/<row[^>]*>.*?<\/row>/m]
      return [] unless first_row

      first_row.scan(/<is><t>([^<]+)<\/t><\/is>/).flatten
    end

    def extract_zip_filenames(data)
      with_tempfile(data) do |path|
        Zip::File.open(path).entries.map(&:name)
      end
    end

    def read_zip_entry(data, entry_name)
      with_tempfile(data) do |path|
        Zip::File.open(path) do |zip|
          entry = zip.find_entry(entry_name)
          entry&.get_input_stream&.read
        end
      end
    end

    def with_tempfile(data)
      f = Tempfile.new([ "xlsx_test", ".xlsx" ])
      f.binmode
      f.write(data)
      f.close
      yield f.path
    ensure
      f&.unlink
    end
end
