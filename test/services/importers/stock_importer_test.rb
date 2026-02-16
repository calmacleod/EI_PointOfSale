# frozen_string_literal: true

require "test_helper"

module Importers
  class StockImporterTest < ActiveSupport::TestCase
    setup do
      @data_import = DataImport.create!(
        file_name: "test.csv",
        status: "pending",
        imported_by: users(:admin)
      )
    end

    test "preview returns summary of CSV" do
      csv = sample_csv
      importer = Importers::StockImporter.new(@data_import)
      preview = importer.preview(csv)

      assert_equal 3, preview[:total_rows]
      assert_includes preview[:categories], "Comics"
      assert_includes preview[:suppliers], "Diamond Comics"
      assert_equal 3, preview[:sample_rows].size
    end

    test "preview detects duplicate codes" do
      csv = <<~CSV
        Stock_Code,Product_Name,Selling_Price,Purchase_Price,Stock_Level,Tax_Applied,Date_Added,Added_By,Fr_Rent_Pts,Pts_To_Rent,Stock_Cat,Reorder_Level,Supplier,Supp_Phone,Order2_Level,OUnit_Cost,Items_Unit,Supp_Ref,Addit_Info,I_Image
        DUP-001,Product A,9.99,4.99,10,2,,,,,"Comics",0,"Diamond Comics","555-1234",0,0,1,,,
        DUP-001,Product B,12.99,6.99,5,2,,,,,"Comics",0,"Diamond Comics","555-1234",0,0,1,,,
      CSV
      importer = Importers::StockImporter.new(@data_import)
      preview = importer.preview(csv)

      assert_equal 1, preview[:duplicate_codes]
    end

    test "preview detects blank codes" do
      csv = <<~CSV
        Stock_Code,Product_Name,Selling_Price,Purchase_Price,Stock_Level,Tax_Applied,Date_Added,Added_By,Fr_Rent_Pts,Pts_To_Rent,Stock_Cat,Reorder_Level,Supplier,Supp_Phone,Order2_Level,OUnit_Cost,Items_Unit,Supp_Ref,Addit_Info,I_Image
        ,Blank Code Product,9.99,4.99,10,2,,,,,"Comics",0,"Diamond Comics","555-1234",0,0,1,,,
        TEST-001,Valid Product,9.99,4.99,10,2,,,,,"Comics",0,"Diamond Comics","555-1234",0,0,1,,,
      CSV
      importer = Importers::StockImporter.new(@data_import)
      preview = importer.preview(csv)

      assert_equal 1, preview[:blank_codes]
    end

    test "execute creates products from CSV" do
      csv = sample_csv
      importer = Importers::StockImporter.new(@data_import)

      assert_difference("Product.count", 3) do
        importer.execute(csv)
      end

      @data_import.reload
      assert_equal "completed", @data_import.status
      assert_equal 3, @data_import.processed_rows
      assert_equal 3, @data_import.created_count

      product = Product.find_by(code: "IMP-001")
      assert_equal "Imported Comic Book", product.name
      assert_equal 12.99, product.selling_price.to_f
      assert_equal 5, product.stock_level
    end

    test "execute creates suppliers from CSV" do
      csv = sample_csv
      importer = Importers::StockImporter.new(@data_import)

      assert_difference("Supplier.count") do
        importer.execute(csv)
      end

      supplier = Supplier.find_by(name: "Diamond Comics")
      assert_equal "555-1234", supplier.phone
    end

    test "execute creates categories from CSV" do
      csv = sample_csv
      importer = Importers::StockImporter.new(@data_import)
      importer.execute(csv)

      assert Category.exists?(name: "Comics")
      assert Category.exists?(name: "TCG")
    end

    test "execute skips blank codes" do
      csv = <<~CSV
        Stock_Code,Product_Name,Selling_Price,Purchase_Price,Stock_Level,Tax_Applied,Date_Added,Added_By,Fr_Rent_Pts,Pts_To_Rent,Stock_Cat,Reorder_Level,Supplier,Supp_Phone,Order2_Level,OUnit_Cost,Items_Unit,Supp_Ref,Addit_Info,I_Image
        ,Blank Code,9.99,4.99,10,2,,,,,"Comics",0,"Diamond Comics","555-1234",0,0,1,,,
        VALID-001,Valid Product,9.99,4.99,10,2,,,,,"Comics",0,"Diamond Comics","555-1234",0,0,1,,,
      CSV

      importer = Importers::StockImporter.new(@data_import)

      assert_difference("Product.count", 1) do
        importer.execute(csv)
      end
    end

    test "execute maps tax codes correctly" do
      csv = <<~CSV
        Stock_Code,Product_Name,Selling_Price,Purchase_Price,Stock_Level,Tax_Applied,Date_Added,Added_By,Fr_Rent_Pts,Pts_To_Rent,Stock_Cat,Reorder_Level,Supplier,Supp_Phone,Order2_Level,OUnit_Cost,Items_Unit,Supp_Ref,Addit_Info,I_Image
        TAX-0,No Tax Item,5.00,2.50,10,0,,,,,"Comics",0,"Diamond Comics","555-1234",0,0,1,,,
        TAX-1,GST Item,10.00,5.00,10,1,,,,,"Comics",0,"Diamond Comics","555-1234",0,0,1,,,
        TAX-2,HST Item,15.00,7.50,10,2,,,,,"Comics",0,"Diamond Comics","555-1234",0,0,1,,,
      CSV

      importer = Importers::StockImporter.new(@data_import)
      importer.execute(csv)

      exempt = TaxCode.find_by(code: "EXEMPT")
      gst = TaxCode.find_by(code: "GST")
      hst = TaxCode.find_by(code: "HST")

      assert_equal exempt, Product.find_by(code: "TAX-0").tax_code, "Tax_Applied 0 should map to EXEMPT"
      assert_equal gst, Product.find_by(code: "TAX-1").tax_code, "Tax_Applied 1 should map to GST"
      assert_equal hst, Product.find_by(code: "TAX-2").tax_code, "Tax_Applied 2 should map to HST"
    end

    test "execute handles re-import (upsert)" do
      Product.create!(code: "IMP-001", name: "Old Name", selling_price: 5.99)

      csv = sample_csv
      importer = Importers::StockImporter.new(@data_import)
      importer.execute(csv)

      product = Product.find_by(code: "IMP-001")
      assert_equal "Imported Comic Book", product.name
      assert_equal 12.99, product.selling_price.to_f
    end

    private

      def sample_csv
        <<~CSV
          Stock_Code,Product_Name,Selling_Price,Purchase_Price,Stock_Level,Tax_Applied,Date_Added,Added_By,Fr_Rent_Pts,Pts_To_Rent,Stock_Cat,Reorder_Level,Supplier,Supp_Phone,Order2_Level,OUnit_Cost,Items_Unit,Supp_Ref,Addit_Info,I_Image
          IMP-001,Imported Comic Book,12.99,6.50,5,1,,,,,"Comics",2,"Diamond Comics","555-1234",10,6.50,1,"REF-001","A great comic",
          IMP-002,Imported Card Pack,4.99,2.50,50,2,,,,,"TCG",10,"Diamond Comics","555-1234",24,2.50,1,"","",
          IMP-003,Imported Figurine,24.99,12.00,3,2,,,,,"Comics",1,"Diamond Comics","555-1234",6,12.00,1,"","Rare figurine",
        CSV
      end
  end
end
