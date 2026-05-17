# frozen_string_literal: true

require "test_helper"

module ReportTemplates
  class BusinessReportsTest < ActiveSupport::TestCase
    setup do
      @start_date = 1.year.ago.to_date.to_s
      @end_date = Date.current.to_s
    end

    test "new report templates are registered" do
      assert_equal SalesSummary, ReportTemplate.find("sales_summary")
      assert_equal PaymentMethodBreakdown, ReportTemplate.find("payment_method_breakdown")
      assert_equal TopSellingItems, ReportTemplate.find("top_selling_items")
      assert_equal TaxCollected, ReportTemplate.find("tax_collected")
      assert_equal CustomerSales, ReportTemplate.find("customer_sales")
      assert_equal InventoryValuation, ReportTemplate.find("inventory_valuation")
    end

    test "sales summary reports daily sales with order detail" do
      result = SalesSummary.generate(start_date: @start_date, end_date: @end_date)

      assert result[:chart][:labels].present?
      assert_equal 3, result[:chart][:datasets].size
      assert result[:summary][:gross_sales].start_with?("$")
      assert result[:summary][:net_sales].start_with?("$")

      order_numbers = result[:table].map { |row| row[:order_number] }
      assert_includes order_numbers, orders(:completed_order).number
    end

    test "payment method breakdown groups completed payments by tender type" do
      result = PaymentMethodBreakdown.generate(start_date: @start_date, end_date: @end_date)

      assert_equal "doughnut", PaymentMethodBreakdown.chart_type
      assert result[:summary][:total_collected].start_with?("$")

      methods = result[:table].map { |row| row[:payment_method] }
      assert_includes methods, "Cash"
      assert_includes methods, "Debit"
      assert_includes methods, "Credit"
    end

    test "top selling items can be filtered to services" do
      service_order = create_completed_order(number: "ORD-SERVICE-REPORT", total: 14.68, tax_total: 1.69, subtotal: 12.99)
      OrderLine.create!(
        order: service_order,
        sellable: services(:printer_refill),
        code: services(:printer_refill).code,
        name: services(:printer_refill).name,
        quantity: 1,
        unit_price: 12.99,
        tax_rate: 0.13,
        tax_amount: 1.69,
        line_total: 14.68,
        tax_code: tax_codes(:one),
        position: 1
      )

      result = TopSellingItems.generate(start_date: @start_date, end_date: @end_date, item_type: "Service")

      assert result[:summary][:net_sales].start_with?("$")
      assert_equal [ "service" ], result[:table].map { |row| row[:item_type].downcase }.uniq
      assert_includes result[:table].map { |row| row[:code] }, services(:printer_refill).code
    end

    test "tax collected reports taxable sales and tax by code" do
      result = TaxCollected.generate(start_date: @start_date, end_date: @end_date)

      assert result[:summary][:tax_collected].start_with?("$")
      assert result[:chart][:datasets].size >= 2

      tax_codes = result[:table].map { |row| row[:tax_code] }
      assert_includes tax_codes, "HST"
    end

    test "customer sales includes and excludes quick sales" do
      create_completed_order(number: "ORD-QUICK-SALE-REPORT", customer: nil)

      with_quick_sales = CustomerSales.generate(start_date: @start_date, end_date: @end_date)
      customer_names = with_quick_sales[:table].map { |row| row[:customer] }
      assert_includes customer_names, "Quick Sale"

      without_quick_sales = CustomerSales.generate(
        start_date: @start_date,
        end_date: @end_date,
        include_quick_sales: "0"
      )
      customer_names = without_quick_sales[:table].map { |row| row[:customer] }
      refute_includes customer_names, "Quick Sale"
    end

    test "inventory valuation values products and supports below reorder scope" do
      product = Product.create!(
        code: "LOW-REPORT-001",
        name: "Low Report Widget",
        stock_level: 1,
        reorder_level: 5,
        purchase_price: 4.00,
        selling_price: 9.00,
        supplier: suppliers(:diamond_comics),
        tax_code: tax_codes(:one)
      )

      result = InventoryValuation.generate(scope: "below_reorder")

      assert result[:summary][:retail_value].start_with?("$")
      assert result[:summary][:cost_value].start_with?("$")

      codes = result[:table].map { |row| row[:code] }
      assert_includes codes, product.code
    end

    private

      def create_completed_order(number:, customer: customers(:acme_corp), subtotal: 10.00, tax_total: 1.30, total: 11.30)
        Order.create!(
          number: number,
          status: :completed,
          created_by: users(:admin),
          customer: customer,
          completed_at: Time.current,
          subtotal: subtotal,
          discount_total: 0,
          tax_total: tax_total,
          total: total
        )
      end
  end
end
