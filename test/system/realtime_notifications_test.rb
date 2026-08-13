# frozen_string_literal: true

require "application_system_test_case"

class RealtimeNotificationsTest < ApplicationSystemTestCase
  setup do
    @admin = users(:admin)
    system_sign_in_as(@admin)
  end

  test "shows live notification toast and increments unread badge" do
    visit root_path
    assert_selector ".app[data-cable-connected='true']", wait: 5
    initial_count = @admin.reload.unread_notifications_count

    NotifyService.call(
      user: @admin,
      title: "Inventory report ready",
      body: "The latest inventory report is ready to review.",
      url: reports_path,
      persistent: true
    )

    assert_selector "[role='status']", text: "Inventory report ready", wait: 5
    assert_selector "a[aria-label='Notifications'][data-count='#{initial_count + 1}']", wait: 5
  end
end
