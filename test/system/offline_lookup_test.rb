# frozen_string_literal: true

require "application_system_test_case"

class OfflineLookupTest < ApplicationSystemTestCase
  setup do
    visit new_session_path
    reset_offline_browser_state
    system_sign_in_as(users(:one))
  end

  test "syncs and searches every supported offline collection" do
    assert_selector "a[aria-label='Offline lookup']", wait: 10
    wait_for_service_worker
    visit offline_path

    assert_text "CACHED PRODUCTS"
    assert_selector '[data-testid="offline-catalog"][data-ready="true"]', wait: 10
    assert_text "#{Product.kept.count} shown · #{Product.kept.count} saved", wait: 10
    set_offline_search(products(:dragon_shield_red).code)
    assert_equal products(:dragon_shield_red).code, find('[data-testid="offline-catalog"]')["data-query"]
    assert_selector '[data-testid="offline-search"]', wait: 5
    assert_text products(:dragon_shield_red).name

    click_offline_tab("services")
    assert_selector '[data-testid="offline-search"][placeholder="Search cached services…"]', wait: 5
    set_offline_search(services(:printer_refill).name)
    assert_text services(:printer_refill).name

    click_offline_tab("customers")
    assert_selector '[data-testid="offline-search"][placeholder="Search cached customers…"]', wait: 5
    set_offline_search(customers(:jane_doe).member_number)
    assert_text customers(:jane_doe).name

    click_offline_tab("tax_codes")
    assert_selector '[data-testid="offline-search"][placeholder="Search cached tax codes…"]', wait: 5
    set_offline_search(tax_codes(:one).code)
    assert_text tax_codes(:one).name
  end

  test "reloads the native lookup and searches cached records without a connection" do
    wait_for_service_worker
    visit offline_path
    assert_selector '[data-testid="offline-catalog"][data-ready="true"]', wait: 10
    assert_text "#{Product.kept.count} shown · #{Product.kept.count} saved", wait: 10

    emulate_network(offline: true)
    page.driver.browser.navigate.refresh

    assert_text "CACHED PRODUCTS", wait: 10
    assert_selector '[data-testid="offline-connection-badge"]', text: "OFFLINE", wait: 10
    assert_no_selector '[data-testid="exit-offline-mode"]'
    set_offline_search(products(:dragon_shield_red).code)
    assert_text products(:dragon_shield_red).name
  ensure
    emulate_network(offline: false)
  end

  test "phone search and all categories are visible without horizontal scrolling" do
    page.current_window.resize_to(390, 844)
    visit offline_path
    assert_selector '[data-testid="offline-catalog"][data-ready="true"]', wait: 10
    controls = [ "offline-search", *%w[products services customers tax_codes].map { |type| "offline-tab-#{type}" } ]
    controls.each do |control|
      bounds = find("[data-testid='#{control}']").evaluate_script("this.getBoundingClientRect().toJSON()")
      assert_operator bounds["left"], :>=, 0, "#{control} starts offscreen"
      assert_operator bounds["right"], :<=, page.evaluate_script("window.innerWidth"), "#{control} ends offscreen"
    end
    set_offline_search(products(:nhl_puck).code)
    assert_text products(:nhl_puck).name
  ensure
    page.current_window.resize_to(1400, 1400)
  end

  test "syncs every page of a large catalog and retains it offline" do
    Product.insert_all!(501.times.map do |i|
      { code: "PAGED-#{i}", name: "Paged product #{i}", selling_price: 1 }
    end)
    wait_for_service_worker
    visit offline_path
    assert_selector '[data-testid="offline-catalog"][data-ready="true"]', wait: 10
    assert_text "20 shown · #{Product.kept.count} saved", wait: 10
    click_button "Full re-sync"
    click_button "Replace and sync"
    assert_button "Sync now", disabled: false, wait: 10
    assert_text "20 shown · #{Product.kept.count} saved"

    emulate_network(offline: true)
    page.driver.browser.navigate.refresh
    assert_selector '[data-testid="offline-catalog"][data-ready="true"]', wait: 10
    set_offline_search("PAGED-500")
    assert_text "Paged product 500", wait: 10
  ensure
    emulate_network(offline: false)
  end

  private

    def reset_offline_browser_state
      # Cookies reset between tests, but the offline catalog and sync timestamps
      # otherwise retain records created by earlier browser tests on this origin.
      page.driver.browser.execute_cdp(
        "Storage.clearDataForOrigin",
        origin: page.evaluate_script("window.location.origin"),
        storageTypes: "indexeddb,local_storage"
      )
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
