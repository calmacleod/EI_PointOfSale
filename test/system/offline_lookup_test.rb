# frozen_string_literal: true

require "application_system_test_case"

class OfflineLookupTest < ApplicationSystemTestCase
  setup do
    visit new_session_path
    reset_offline_browser_state
    system_sign_in_as(users(:one))
  end

  test "syncs and searches every supported offline collection" do
    assert_link "Offline lookup", wait: 10
    wait_for_service_worker
    visit offline_path

    assert_text "Cached lookup"
    assert_selector '[data-testid="offline-catalog"][data-ready="true"]', wait: 10
    assert_text "#{Product.kept.count} products saved", wait: 10
    set_offline_search(products(:dragon_shield_red).code)
    assert_equal products(:dragon_shield_red).code, find('[data-testid="offline-catalog"]')["data-query"]
    assert_field "Search cached products", with: products(:dragon_shield_red).code
    assert_text products(:dragon_shield_red).name

    click_offline_tab("services")
    assert_field "Search cached services", wait: 5
    set_offline_search(services(:printer_refill).name)
    assert_text services(:printer_refill).name

    click_offline_tab("customers")
    assert_field "Search cached customers", wait: 5
    set_offline_search(customers(:jane_doe).member_number)
    assert_text customers(:jane_doe).name

    click_offline_tab("tax_codes")
    assert_field "Search cached tax codes", wait: 5
    set_offline_search(tax_codes(:one).code)
    assert_text tax_codes(:one).name
  end

  test "reloads the native lookup and searches cached records without a connection" do
    wait_for_service_worker
    visit offline_path
    assert_selector '[data-testid="offline-catalog"][data-ready="true"]', wait: 10
    assert_text "#{Product.kept.count} products saved", wait: 10

    emulate_network(offline: true)
    page.driver.browser.navigate.refresh

    assert_text "Cached lookup", wait: 10
    assert_selector '[data-testid="offline-connection-badge"]', text: "Offline", wait: 10
    assert_no_selector '[data-testid="exit-offline-mode"]'
    set_offline_search(products(:dragon_shield_red).code)
    assert_text products(:dragon_shield_red).name
  ensure
    emulate_network(offline: false)
  end

  private

    def reset_offline_browser_state
      page.driver.browser.execute_async_script(<<~JAVASCRIPT)
        const done = arguments[0]
        Promise.all([
          caches.keys().then((keys) => Promise.all(keys.map((key) => caches.delete(key)))),
          navigator.serviceWorker.getRegistrations().then((registrations) => Promise.all(registrations.map((registration) => registration.unregister())))
        ]).then(() => done(true)).catch(() => done(false))
      JAVASCRIPT
    end

    def wait_for_service_worker
      page.driver.browser.execute_async_script(<<~JAVASCRIPT)
        const done = arguments[0]
        navigator.serviceWorker.ready
          .then(() => new Promise((resolve) => window.setTimeout(resolve, 500)))
          .then(() => done(true))
          .catch(() => done(false))
      JAVASCRIPT
    end

    def click_offline_tab(tab)
      page.execute_script("document.querySelector('[data-testid=offline-tab-#{tab}]').click()")
    end

    def emulate_network(offline:)
      page.driver.browser.execute_cdp("Network.enable")
      page.driver.browser.execute_cdp(
        "Network.emulateNetworkConditions",
        offline: offline,
        latency: 0,
        downloadThroughput: offline ? 0 : -1,
        uploadThroughput: offline ? 0 : -1,
        connectionType: offline ? "none" : "wifi"
      )
    end

    def set_offline_search(value)
      page.execute_script(<<~JAVASCRIPT, value)
        const input = document.querySelector('[data-testid="offline-search"]')
        input.value = arguments[0]
        input.dispatchEvent(new Event('input', { bubbles: true }))
      JAVASCRIPT
    end
end
