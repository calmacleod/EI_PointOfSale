# frozen_string_literal: true

require "test_helper"

class RequestQueryPerformanceTest < ActionDispatch::IntegrationTest
  setup do
    @admin = users(:admin)
    sign_in_as(@admin)
  end

  test "register query count stays bounded with many line items" do
    order = orders(:draft_order)
    product = products(:dragon_shield_red)
    12.times { |index| add_order_line(order, product, index + 1) }

    queries = assert_queries_at_most(18, label: "Register page") do
      get register_path(order_id: order.id)
    end

    assert_response :success
    assert_equal 1, queries.count { |sql| sql.include?(%("refund_lines")) },
      "refund quantities should be preloaded in one query"
  end

  test "quick lookup query count does not grow with order size" do
    product = products(:dragon_shield_red)
    small_order = prepared_order(product, line_count: 1)
    large_order = prepared_order(product, line_count: 12)

    small_queries = capture_sql_queries do
      post quick_lookup_orders_path, params: { order_id: small_order.id, code: product.code }
    end
    assert_redirected_to register_path(order_id: small_order.id)

    large_queries = assert_queries_at_most(25, label: "Quick lookup with 12 lines") do
      post quick_lookup_orders_path, params: { order_id: large_order.id, code: product.code }
    end
    assert_redirected_to register_path(order_id: large_order.id)
    assert_operator large_queries.length, :<=, small_queries.length + 2,
      "Quick lookup reads should stay bounded as line count grows"
  end

  test "product index query count stays bounded with a full page of products" do
    20.times do |index|
      Product.create!(
        code: "PERF-#{index}", name: "Performance product #{index}",
        selling_price: 10, stock_level: index, tax_code: tax_codes(:one),
        supplier: suppliers(:diamond_comics), added_by: @admin
      )
    end

    assert_queries_at_most(15, label: "Product index") { get products_path }
    assert_response :success
    assert_operator inertia_props.fetch("rows").length, :>=, 20
  end

  test "customer search query count stays bounded across many matches" do
    20.times do |index|
      Customer.create!(
        name: "Performance customer #{index}", email: "performance#{index}@example.com",
        active: true, tax_code: tax_codes(:one), added_by: @admin
      )
    end

    assert_queries_at_most(4, label: "Customer search API") do
      get search_customers_path, params: { q: "Performance" }, as: :json
    end
    assert_response :success
    assert_equal 15, response.parsed_body.fetch("results").length
  end

  private

    def add_order_line(order, product, position)
      line = order.order_lines.build(quantity: 1, position: position)
      line.snapshot_from_sellable!(product)
      line.save!
    end

    def prepared_order(product, line_count:)
      order = Order.create!(created_by: @admin)
      line_count.times { |index| add_order_line(order, product, index + 1) }
      state = Discounts::AutoApply.call(order)
      Orders::CalculateTotals.call(order, state:)
      order
    end
end
