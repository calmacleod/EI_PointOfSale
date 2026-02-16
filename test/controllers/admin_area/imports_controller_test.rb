# frozen_string_literal: true

require "test_helper"

module AdminArea
  class ImportsControllerTest < ActionDispatch::IntegrationTest
    test "new renders for admin" do
      sign_in_as(users(:admin))

      get new_admin_import_path
      assert_response :success
      assert_includes response.body, "Data Import"
    end

    test "new is not accessible to common users" do
      sign_in_as(users(:one))

      get new_admin_import_path
      assert_redirected_to root_path
    end

    test "create with preview renders preview" do
      sign_in_as(users(:admin))

      csv = fixture_csv_content
      file = Rack::Test::UploadedFile.new(StringIO.new(csv), "text/csv", true, original_filename: "test_stock.csv")

      post admin_imports_path, params: { file: file, preview: "1" }

      assert_response :success
      assert_includes response.body, "Import Preview"
      assert_includes response.body, "Sample rows"
    end

    test "create without preview starts import" do
      sign_in_as(users(:admin))

      csv = fixture_csv_content
      file = Rack::Test::UploadedFile.new(StringIO.new(csv), "text/csv", true, original_filename: "test_stock.csv")

      assert_enqueued_with(job: Importers::StockImportJob) do
        post admin_imports_path, params: { file: file, import: "1" }
      end

      assert_redirected_to admin_import_path(DataImport.last)
    end

    test "create without file redirects with error" do
      sign_in_as(users(:admin))

      post admin_imports_path
      assert_redirected_to new_admin_import_path
      assert_equal "Please select a CSV file.", flash[:alert]
    end

    test "show renders import status" do
      sign_in_as(users(:admin))
      data_import = DataImport.create!(
        file_name: "test.csv",
        status: "completed",
        total_rows: 100,
        processed_rows: 100,
        created_count: 95,
        updated_count: 5,
        imported_by: users(:admin)
      )

      get admin_import_path(data_import)
      assert_response :success
      assert_includes response.body, "test.csv"
      assert_includes response.body, "Completed"
    end

    private

      def fixture_csv_content
        <<~CSV
          Stock_Code,Product_Name,Selling_Price,Purchase_Price,Stock_Level,Tax_Applied,Date_Added,Added_By,Fr_Rent_Pts,Pts_To_Rent,Stock_Cat,Reorder_Level,Supplier,Supp_Phone,Order2_Level,OUnit_Cost,Items_Unit,Supp_Ref,Addit_Info,I_Image
          TEST-CSV-001,Test Product One,9.99,4.99,10,2,,,,,"Comics",0,"Test Supplier","555-0000",0,0,1,,,
          TEST-CSV-002,Test Product Two,14.99,7.50,20,1,,,,,"TCG",5,"Test Supplier","555-0000",10,7.50,1,,,
        CSV
      end
  end
end
