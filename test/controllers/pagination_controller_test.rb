# frozen_string_literal: true

require "test_helper"

class PaginationControllerTest < ActionDispatch::IntegrationTest
  setup do
    @admin = users(:admin)
    sign_in_as(@admin)
  end

  test "every Pagy-backed index exposes the shared pagination contract" do
    paginated_paths.each do |path|
      get path

      assert_response :success
      pagination = inertia_props["pagination"]
      assert pagination, "Expected #{path} to expose pagination"
      assert_equal %w[count from limit next page pages previous to], pagination.keys.sort, "Unexpected pagination contract for #{path}"
    end
  end

  test "pagination reports both directions and the current record range" do
    28.times do |index|
      Product.create!(
        code: "PAGE-#{index}", name: "Pagination product #{index}",
        selling_price: 10, stock_level: index, tax_code: tax_codes(:one),
        supplier: suppliers(:diamond_comics), added_by: @admin
      )
    end

    get products_path(q: "Pagination product")
    assert_equal({ "page" => 1, "pages" => 2, "count" => 28, "previous" => nil, "next" => 2, "limit" => 25, "from" => 1, "to" => 25 }, inertia_props["pagination"])

    get products_path(q: "Pagination product", page: 2)
    assert_equal({ "page" => 2, "pages" => 2, "count" => 28, "previous" => 1, "next" => nil, "limit" => 25, "from" => 26, "to" => 28 }, inertia_props["pagination"])
    assert_equal 3, inertia_props["rows"].length
  end

  private

    def paginated_paths
      [
        products_path,
        services_path,
        customers_path,
        store_tasks_path,
        reports_path,
        orders_path,
        held_orders_path,
        admin_users_path,
        admin_tax_codes_path,
        admin_suppliers_path,
        admin_discounts_path,
        admin_gift_certificates_path,
        admin_receipt_templates_path,
        admin_audits_path,
        history_cash_drawer_path,
        product_restocks_path(products(:dragon_shield_red))
      ]
    end
end
