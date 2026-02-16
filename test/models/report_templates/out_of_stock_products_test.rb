# frozen_string_literal: true

require "test_helper"

module ReportTemplates
  class OutOfStockProductsTest < ActiveSupport::TestCase
    setup do
      @supplier = suppliers(:diamond_comics)

      @out_of_stock = Product.create!(
        code: "OOS-001", name: "Out of Stock Widget",
        stock_level: 0, reorder_level: 5, selling_price: 9.99,
        supplier: @supplier
      )
      @negative_stock = Product.create!(
        code: "OOS-002", name: "Negative Stock Gadget",
        stock_level: -3, reorder_level: 2, selling_price: 19.99,
        supplier: @supplier
      )
      @below_reorder = Product.create!(
        code: "LOW-001", name: "Low Stock Gizmo",
        stock_level: 2, reorder_level: 10, selling_price: 29.99,
        supplier: suppliers(:jf_sports)
      )
    end

    test "is registered in the template registry" do
      template = ReportTemplate.find("out_of_stock_products")
      assert_equal OutOfStockProducts, template
    end

    test "has required class methods" do
      assert_equal "out_of_stock_products", OutOfStockProducts.key
      assert_equal "Out of stock products", OutOfStockProducts.title
      assert OutOfStockProducts.description.present?
      assert_equal "bar", OutOfStockProducts.chart_type
    end

    test "parameters defines a scope select" do
      params = OutOfStockProducts.parameters
      assert_equal 1, params.size
      assert_equal :scope, params[0][:key]
      assert_equal :select, params[0][:type]
    end

    test "table_columns defines expected columns" do
      columns = OutOfStockProducts.table_columns
      keys = columns.map { |c| c[:key] }
      assert_includes keys, :code
      assert_includes keys, :name
      assert_includes keys, :supplier
      assert_includes keys, :stock_level
      assert_includes keys, :reorder_level
      assert_includes keys, :selling_price
    end

    test "generate with out_of_stock scope returns only zero/negative stock" do
      result = OutOfStockProducts.generate(scope: "out_of_stock")

      assert result[:chart].present?
      assert result[:table].is_a?(Array)
      assert result[:summary].is_a?(Hash)

      codes = result[:table].map { |r| r[:code] }
      assert_includes codes, "OOS-001"
      assert_includes codes, "OOS-002"
      refute_includes codes, "LOW-001"  # stock_level 2 > 0
    end

    test "generate with below_reorder scope includes low stock items" do
      result = OutOfStockProducts.generate(scope: "below_reorder")

      codes = result[:table].map { |r| r[:code] }
      assert_includes codes, "OOS-001"
      assert_includes codes, "OOS-002"
      assert_includes codes, "LOW-001"
    end

    test "generate chart groups products by supplier" do
      result = OutOfStockProducts.generate(scope: "out_of_stock")
      chart = result[:chart]

      assert chart[:labels].is_a?(Array)
      assert chart[:datasets].first[:data].is_a?(Array)
      assert_includes chart[:labels], "Diamond Comics Distribution"
    end

    test "generate summary includes total and supplier count" do
      result = OutOfStockProducts.generate(scope: "out_of_stock")
      summary = result[:summary]

      assert summary[:total_products] >= 2
      assert summary[:suppliers_affected] >= 1
      assert_equal "Out of stock (≤ 0)", summary[:scope_label]
      assert summary[:total_retail_value].start_with?("$")
    end

    test "generate excludes discarded products" do
      @out_of_stock.discard

      result = OutOfStockProducts.generate(scope: "out_of_stock")
      codes = result[:table].map { |r| r[:code] }
      refute_includes codes, "OOS-001"
    end

    test "generate does not include table_note when under limit" do
      result = OutOfStockProducts.generate(scope: "out_of_stock")
      assert_nil result[:summary][:table_note]
    end

    test "generate truncates table and adds note when over limit" do
      original_limit = OutOfStockProducts::TABLE_LIMIT
      OutOfStockProducts.send(:remove_const, :TABLE_LIMIT)
      OutOfStockProducts.const_set(:TABLE_LIMIT, 1)

      result = OutOfStockProducts.generate(scope: "out_of_stock")

      assert_equal 1, result[:table].size
      assert result[:summary][:total_products] > 1
      assert_match(/Showing first 1 of/, result[:summary][:table_note])
    ensure
      OutOfStockProducts.send(:remove_const, :TABLE_LIMIT)
      OutOfStockProducts.const_set(:TABLE_LIMIT, original_limit)
    end
  end
end
