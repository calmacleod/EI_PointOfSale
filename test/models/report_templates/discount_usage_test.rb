# frozen_string_literal: true

require "test_helper"

module ReportTemplates
  class DiscountUsageTest < ActiveSupport::TestCase
    setup do
      @discount = discounts(:percentage_all)
      @completed_order = orders(:completed_order)
      @held_order = orders(:held_order)
      @completed_line = order_lines(:completed_line_one)
      @held_line = order_lines(:held_line)

      # Create order-level discount for completed order
      @order_discount = OrderDiscount.create!(
        order: @completed_order,
        discount: @discount,
        name: @discount.name,
        discount_type: :percentage,
        value: 10.00,
        calculated_amount: 3.00,
        scope: :all_items
      )

      # Create line-level discount for held order
      @line_discount = OrderLineDiscount.create!(
        order_line: @held_line,
        source_discount: @discount,
        name: @discount.name,
        discount_type: :percentage,
        value: 10.00,
        calculated_amount: 1.50,
        excluded_quantity: 0,
        auto_applied: true
      )

      # Complete the held order from fixture so we have a completed order with line discount
      @completed_order_with_line_discount = Order.create!(
        number: "ORD-COMPLETED-LINE-DISCOUNT",
        status: :completed,
        created_by: users(:admin),
        customer: customers(:acme_corp),
        completed_at: 2.days.ago,
        subtotal: 29.98,
        discount_total: 3.00,
        tax_total: 3.90,
        total: 30.88
      )

      @completed_line_with_discount = OrderLine.create!(
        order: @completed_order_with_line_discount,
        sellable: products(:dragon_shield_red),
        code: "DS-MAT-RED",
        name: "Dragon Shield Matte Sleeves - Red",
        quantity: 2,
        unit_price: 14.99,
        tax_rate: 0.13,
        tax_amount: 3.90,
        line_total: 30.88,
        tax_code: tax_codes(:one),
        position: 1
      )

      OrderLineDiscount.create!(
        order_line: @completed_line_with_discount,
        source_discount: @discount,
        name: @discount.name,
        discount_type: :percentage,
        value: 10.00,
        calculated_amount: 3.00,
        excluded_quantity: 0,
        auto_applied: true
      )
    end

    test "is registered in the template registry" do
      template = ReportTemplate.find("discount_usage")
      assert_equal DiscountUsage, template
    end

    test "has required class methods" do
      assert_equal "discount_usage", DiscountUsage.key
      assert_equal "Discount usage", DiscountUsage.title
      assert DiscountUsage.description.present?
      assert_equal "line", DiscountUsage.chart_type
    end

    test "parameters defines date range and optional discount select" do
      params = DiscountUsage.parameters

      assert_equal 3, params.size

      assert_equal :start_date, params[0][:key]
      assert_equal :date, params[0][:type]
      assert_equal false, params[0][:required]

      assert_equal :end_date, params[1][:key]
      assert_equal :date, params[1][:type]
      assert_equal false, params[1][:required]

      assert_equal :discount_id, params[2][:key]
      assert_equal :select, params[2][:type]
      assert_equal false, params[2][:required]
      assert params[2][:options].is_a?(Array)
    end

    test "table_columns defines expected columns" do
      columns = DiscountUsage.table_columns
      keys = columns.map { |c| c[:key] }

      assert_includes keys, :order_number
      assert_includes keys, :order_date
      assert_includes keys, :customer_name
      assert_includes keys, :discount_names
      assert_includes keys, :discount_amount
      assert_includes keys, :order_total
    end

    test "generate returns chart data with two charts" do
      result = DiscountUsage.generate(
        start_date: 7.days.ago.to_date.to_s,
        end_date: Date.current.to_s
      )

      assert result[:chart].present?
      assert result[:chart][:discount_analysis].present?
      assert result[:chart][:order_counts].present?

      assert result[:chart][:discount_analysis][:labels].is_a?(Array)
      assert result[:chart][:discount_analysis][:datasets].is_a?(Array)
      assert_equal 2, result[:chart][:discount_analysis][:datasets].size

      assert result[:chart][:order_counts][:labels].is_a?(Array)
      assert result[:chart][:order_counts][:datasets].is_a?(Array)
    end

    test "generate returns completed orders table" do
      result = DiscountUsage.generate(
        start_date: 7.days.ago.to_date.to_s,
        end_date: Date.current.to_s
      )

      assert result[:table].is_a?(Array)
      assert result[:table].size >= 2 # Our test orders

      order_numbers = result[:table].map { |r| r[:order_number] }
      assert_includes order_numbers, @completed_order.number
      assert_includes order_numbers, @completed_order_with_line_discount.number
    end

    test "generate returns held orders table separately" do
      result = DiscountUsage.generate(
        start_date: 7.days.ago.to_date.to_s,
        end_date: Date.current.to_s
      )

      assert result[:held_orders_table].is_a?(Array)
      assert result[:held_orders_table].size >= 1

      order_numbers = result[:held_orders_table].map { |r| r[:order_number] }
      assert_includes order_numbers, @held_order.number
    end

    test "generate returns summary with big numbers" do
      result = DiscountUsage.generate(
        start_date: 7.days.ago.to_date.to_s,
        end_date: Date.current.to_s
      )

      assert result[:summary].present?
      assert result[:summary][:total_discount_amount].present?
      assert result[:summary][:total_orders].present?
      assert result[:summary][:average_discount_per_order].present?
      assert result[:summary][:date_range].present?

      # Summary should only include completed orders
      assert result[:summary][:total_orders].to_i >= 2
      assert result[:summary][:total_discount_amount].start_with?("$")
    end

    test "generate filters by specific discount when discount_id provided" do
      other_discount = Discount.create!(
        name: "Other Discount",
        discount_type: :percentage,
        value: 20.00,
        active: true,
        applies_to_all: true
      )

      other_order = Order.create!(
        number: "ORD-OTHER-DISCOUNT",
        status: :completed,
        created_by: users(:admin),
        completed_at: 1.day.ago,
        subtotal: 100.00,
        discount_total: 20.00,
        tax_total: 0,
        total: 80.00
      )

      OrderDiscount.create!(
        order: other_order,
        discount: other_discount,
        name: other_discount.name,
        discount_type: :percentage,
        value: 20.00,
        calculated_amount: 20.00,
        scope: :all_items
      )

      # Generate report for specific discount
      result = DiscountUsage.generate(
        start_date: 7.days.ago.to_date.to_s,
        end_date: Date.current.to_s,
        discount_id: other_discount.id.to_s
      )

      order_numbers = result[:table].map { |r| r[:order_number] }
      assert_includes order_numbers, other_order.number
      refute_includes order_numbers, @completed_order.number
    end

    test "generate uses default date range when dates not provided" do
      result = DiscountUsage.generate({})

      assert result[:summary][:date_range].present?
      # Should be "30 days ago – today" roughly
      assert result[:chart][:discount_analysis][:labels].is_a?(Array)
    end

    test "generate handles date range with no orders" do
      result = DiscountUsage.generate(
        start_date: "2020-01-01",
        end_date: "2020-01-07"
      )

      assert result[:table].is_a?(Array)
      assert result[:held_orders_table].is_a?(Array)
      assert result[:summary][:total_orders], "0"
      assert result[:summary][:total_discount_amount], "$0.00"
    end

    test "generate table includes discount details" do
      result = DiscountUsage.generate(
        start_date: 7.days.ago.to_date.to_s,
        end_date: Date.current.to_s
      )

      completed_row = result[:table].find { |r| r[:order_number] == @completed_order.number }

      assert completed_row[:order_date].present?
      assert completed_row[:customer_name].present?
      assert completed_row[:discount_names].include?(@discount.name)
      assert completed_row[:discount_amount].start_with?("$")
      assert completed_row[:order_total].start_with?("$")
    end

    test "held orders use created_at for date field" do
      result = DiscountUsage.generate(
        start_date: 7.days.ago.to_date.to_s,
        end_date: Date.current.to_s
      )

      held_row = result[:held_orders_table].find { |r| r[:order_number] == @held_order.number }

      assert held_row.present?
      assert held_row[:order_date].present?
    end

    test "generate aggregates daily data correctly" do
      result = DiscountUsage.generate(
        start_date: 7.days.ago.to_date.to_s,
        end_date: Date.current.to_s
      )

      # Both charts should have the same labels (dates)
      assert_equal result[:chart][:discount_analysis][:labels],
                   result[:chart][:order_counts][:labels]

      # Data arrays should match labels length
      labels_count = result[:chart][:discount_analysis][:labels].size
      # discount_analysis has 2 datasets (order_totals and discount_amounts)
      assert_equal labels_count,
                   result[:chart][:discount_analysis][:datasets][0][:data].size
      assert_equal labels_count,
                   result[:chart][:order_counts][:datasets].first[:data].size
    end

    test "generate includes both order-level and line-level discounts in totals" do
      result = DiscountUsage.generate(
        start_date: 7.days.ago.to_date.to_s,
        end_date: Date.current.to_s
      )

      completed_row = result[:table].find { |r| r[:order_number] == @completed_order_with_line_discount.number }

      # Should show the line-level discount amount
      assert completed_row[:discount_amount].start_with?("$")
      # Line discount was $3.00
      assert completed_row[:discount_amount].include?("3.00") || completed_row[:discount_amount].include?("3")
    end

    test "discount_options includes all discounts" do
      options = DiscountUsage.discount_options

      assert options.is_a?(Array)
      assert_equal [ "All discounts", "" ], options.first

      # Should include fixture discounts
      discount_names = options.map(&:first)
      assert_includes discount_names, @discount.name
    end
  end
end
