require "application_system_test_case"

class HelpTest < ApplicationSystemTestCase
  setup { system_sign_in_as(users(:one)) }

  test "help search finds behavior in document bodies and opens a guide" do
    visit help_path
    assert_selector "h1", text: "How can we help?"
    fill_in "Search the guide", with: "three cents"
    within ".help-home" do
      assert_selector "h1", text: "Search results"
      click_link "Taking payments"
    end
    assert_current_path help_article_path("payments")
    assert_selector "h1", text: "Taking payments"
    assert_text "Recording a payment does not charge a card."
    assert_selector 'a[href="#split-and-round"]'
    click_link "Open this feature"
    assert_current_path register_path
    assert_field "code"
  end

  test "contextual help and F1 open the register guide" do
    visit register_path
    click_link "Help for this screen"
    assert_current_path help_article_path("register")
    assert_selector "h1", text: "Using the register"
    visit products_path
    find("body").send_keys(:f1)
    assert_current_path help_article_path("products")
    assert_selector "h1", text: "Products"
  end

  test "empty search can be cleared and staff do not see administrator documents" do
    visit help_path
    assert_no_text "Shopify synchronization"
    fill_in "Search the guide", with: "unfindable-help-topic-123"
    assert_text "No matching documents"
    click_button "Show all guides"
    assert_selector "h1", text: "How can we help?"
    assert_field "Search the guide", with: ""
  end

  test "guides can be read on narrow screens and expose a document menu" do
    page.driver.browser.manage.window.resize_to(650, 900)
    visit help_article_path("register")
    assert_selector "h1", text: "Using the register"
    click_button "Browse guides"
    within "nav[aria-label='Help documents']" do
      click_link "Taking payments"
    end
    assert_selector "h1", text: "Taking payments"
    assert page.evaluate_script("document.documentElement.scrollWidth <= window.innerWidth")
  ensure
    page.driver.browser.manage.window.resize_to(1400, 1400)
  end

  test "printing a dark-theme guide uses readable paper colors" do
    visit help_article_path("register")
    assert_selector "h1", text: "Using the register"
    page.execute_script("document.documentElement.dataset.theme = 'dark'")
    page.driver.browser.execute_cdp("Emulation.setEmulatedMedia", media: "print")
    colors = page.evaluate_script("(() => { const style = getComputedStyle(document.querySelector('.help-screen')); return [style.color, style.backgroundColor] })()")
    assert_equal [ "rgb(0, 0, 0)", "rgb(255, 255, 255)" ], colors
    assert_no_selector ".help-sidebar"
    assert_no_button "Print guide"
  ensure
    page.driver.browser.execute_cdp("Emulation.setEmulatedMedia", media: "screen")
  end
end
