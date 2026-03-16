# frozen_string_literal: true

module TurboStreamTestHelper
  TURBO_HEADERS = { "Accept" => "text/vnd.turbo-stream.html" }.freeze

  # Standard order panel target groups
  ORDER_PANELS = %w[order_discounts_panel order_line_items order_totals].freeze
  ORDER_PANELS_WITH_PAYMENTS = %w[order_line_items order_discounts_panel order_totals order_payments_panel].freeze
  PAYMENT_PANELS = %w[order_payments_panel order_totals order_action_buttons].freeze

  def assert_turbo_stream_replaces(*targets)
    targets.flatten.each do |target|
      assert_select(
        "turbo-stream[action='replace'][target='#{target}']",
        { minimum: 1 },
        "Expected turbo stream to replace target '#{target}'"
      )
    end
  end

  def assert_turbo_stream_updates(*targets)
    targets.flatten.each do |target|
      assert_select(
        "turbo-stream[action='update'][target='#{target}']",
        { minimum: 1 },
        "Expected turbo stream to update target '#{target}'"
      )
    end
  end

  def assert_turbo_stream_appends(target)
    assert_select "turbo-stream[action='append'][target='#{target}']"
  end

  def assert_turbo_stream_removes(target)
    assert_select "turbo-stream[action='remove'][target='#{target}']"
  end
end

ActiveSupport.on_load(:action_dispatch_integration_test) do
  include TurboStreamTestHelper
end
