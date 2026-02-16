require "test_helper"

class DataImportTest < ActiveSupport::TestCase
  test "valid with default status" do
    data_import = DataImport.new(file_name: "test.csv")
    assert data_import.valid?
  end

  test "invalid with unknown status" do
    data_import = DataImport.new(file_name: "test.csv", status: "unknown")
    assert_not data_import.valid?
  end

  test "progress_percentage calculates correctly" do
    data_import = DataImport.new(total_rows: 100, processed_rows: 75)
    assert_equal 75, data_import.progress_percentage
  end

  test "progress_percentage returns 0 when no total_rows" do
    data_import = DataImport.new(total_rows: nil)
    assert_equal 0, data_import.progress_percentage
  end

  test "status predicates work" do
    data_import = DataImport.new(status: "processing")
    assert data_import.processing?
    assert_not data_import.completed?
    assert_not data_import.failed?

    data_import.status = "completed"
    assert data_import.completed?
  end
end
