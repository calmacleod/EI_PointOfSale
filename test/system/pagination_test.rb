# frozen_string_literal: true

require "application_system_test_case"

class PaginationTest < ApplicationSystemTestCase
  setup do
    @admin = users(:admin)
    system_sign_in_as(@admin)

    28.times do |index|
      Product.create!(
        code: "SYSTEM-PAGE-#{index}", name: "Pagination browser product #{index}",
        selling_price: 10, stock_level: index, tax_code: tax_codes(:one),
        supplier: suppliers(:diamond_comics), added_by: @admin
      )
    end
  end

  test "moves between pages while preserving the active query" do
    visit products_path(q: "Pagination browser product")

    within "[data-testid='pagination']" do
      assert_text "Rows 1–25 of 28"
      assert_selector "[aria-current='page']", text: "1"
      click_link "Next"
    end

    assert_current_path(/page=2/)
    assert_current_path(/q=Pagination(?:\+|%20)browser(?:\+|%20)product/)
    within "[data-testid='pagination']" do
      assert_text "Rows 26–28 of 28"
      assert_selector "[aria-current='page']", text: "2"
      click_link "Previous"
    end

    within "[data-testid='pagination']" do
      assert_text "Rows 1–25 of 28"
      assert_selector "[aria-current='page']", text: "1"
    end
  end
end
