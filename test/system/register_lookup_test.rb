require "application_system_test_case"
require_relative "../test_helpers/register_helper"

class RegisterLookupTest < ApplicationSystemTestCase
  include RegisterHelper

  setup do
    system_sign_in_as(users(:admin))
    Discount.update_all(active: false)
  end

  test "cashier can search a name and add a product with the keyboard" do
    visit register_path
    fill_in "code", with: "Dragon Shield Matte Red"
    assert_selector "#register-item-results", text: "DS-MAT-RED"
    find("#code").send_keys(:arrow_down, :enter)
    assert_no_selector "[data-testid='pending-register-code']"
    assert_line_item(code: "DS-MAT-RED", name: "Dragon Shield")
    assert_totals_panel(subtotal: 14.99, tax: 1.95, total: 16.94)
    assert_field "code", with: ""
  end

  test "cashier can add a service without a code from search results" do
    Service.create!(name: "Personal consultation", price: 25)
    visit register_path
    fill_in "code", with: "Personal consult"
    within "#register-item-results" do
      click_button "Personal consultation"
    end
    assert_line_item(code: nil, name: "Personal consultation")
    assert_totals_panel(subtotal: 25, tax: 0, total: 25)
  end

  test "rapid scans finish in sequence without a page reload or stealing input focus" do
    visit register_path
    page.execute_script <<~JS
      window.registerWrites = [];
      const originalFetch = window.fetch.bind(window);
      window.fetch = (url, options) => {
        if (String(url).includes('/orders/quick_lookup')) {
          window.registerWrites.push(JSON.parse(options.body));
          return new Promise(resolve => setTimeout(() => resolve(originalFetch(url, options)), 250));
        }
        return originalFetch(url, options);
      };
      performance.clearResourceTimings();
    JS
    [ "DS-MAT-RED", "DS-MAT-RED", "SVC-REFILL-SM" ].each do |code|
      fill_in "code", with: code
      find("#code").send_keys(:enter)
    end
    fill_in "Find customer", with: "Acme"
    assert_no_selector "[data-testid='pending-register-code']", wait: 10
    assert_totals_panel(subtotal: 42.97, tax: 5.59, total: 48.56)
    assert_equal "customer-search", page.evaluate_script("document.activeElement.id")
    assert_equal 3, page.evaluate_script("window.registerWrites.length")
    register_visits = page.evaluate_script("performance.getEntriesByType('resource').filter(entry => new URL(entry.name).pathname === '/register').length")
    assert_equal 0, register_visits
    # The client-side update must also replace Inertia's history snapshot.
    find('a[aria-label="Products"]').click
    assert_current_path products_path
    page.go_back
    assert_current_path register_path
    assert_totals_panel(subtotal: 42.97, tax: 5.59, total: 48.56)
  end

  test "a failed scan stays visible while subsequent scans succeed" do
    visit register_path
    fill_in "code", with: "NONEXISTENT"
    find("#code").send_keys(:enter)
    assert_selector "#lookup_flash", text: "No product or service found"
    fill_in_code_lookup("DS-MAT-RED")
    assert_selector "#lookup_flash", text: "NONEXISTENT"
    assert_button "Take payment", disabled: true
    click_button "Reviewed"
    assert_button "Take payment", disabled: false
    assert_totals_panel(subtotal: 14.99, tax: 1.95, total: 16.94)
  end
end
