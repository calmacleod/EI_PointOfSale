# frozen_string_literal: true

require "application_system_test_case"

class FrontendPerformanceTest < ApplicationSystemTestCase
  setup do
    system_sign_in_as(users(:admin))
  end

  test "prefetches sidebar destinations on hover" do
    visit root_path
    page.execute_script(<<~JAVASCRIPT)
      document.addEventListener("inertia:prefetching", (event) => {
        document.documentElement.dataset.prefetchedPath = event.detail.visit.url.pathname
      })
    JAVASCRIPT

    find("a[aria-label='Products']").hover

    assert_selector "html[data-prefetched-path='#{products_path}']", wait: 5
  end

  test "adds register products without starting the progress bar" do
    visit register_path
    page.execute_script(<<~JAVASCRIPT)
      document.addEventListener("inertia:start", (event) => {
        if (event.detail.visit.url.pathname === "#{quick_lookup_orders_path}") {
          document.documentElement.dataset.quickLookupProgress = String(event.detail.visit.showProgress)
        }
      })
    JAVASCRIPT

    fill_in "code", with: products(:dragon_shield_red).code
    click_button "Add"

    assert_selector "html[data-quick-lookup-progress='false']", wait: 5
    assert_text products(:dragon_shield_red).name, wait: 5
    assert_no_selector "#nprogress"
  end

  test "hydrates deferred product filters after the product table renders" do
    visit products_path

    assert_text products(:dragon_shield_red).name
    assert_button "Add filter", wait: 5

    click_button "Add filter"

    assert_text(/Supplier/i)
    assert_text(/Categories/i)
  end
end
