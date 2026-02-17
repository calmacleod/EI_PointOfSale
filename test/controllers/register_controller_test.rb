# frozen_string_literal: true

require "test_helper"

class RegisterControllerTest < ActionDispatch::IntegrationTest
  setup do
    @admin = users(:admin)
    sign_in_as(@admin)
  end

  test "GET /register shows the register page" do
    get register_path
    assert_response :success
  end

  test "GET /register creates a draft order if none exist" do
    Order.draft.update_all(status: :completed, completed_at: Time.current)
    assert_difference "Order.count", 1 do
      get register_path
    end
    assert_response :success
    assert Order.last.draft?
  end

  test "GET /register with order_id shows that order" do
    order = orders(:draft_order)
    get register_path(order_id: order.id)
    assert_response :success
    assert_select "h1", text: order.number
  end

  test "GET /register falls back to draft if order_id is invalid" do
    get register_path(order_id: 999_999)
    assert_response :success
  end

  test "POST /register/new_order creates a new draft and redirects" do
    assert_difference "Order.count", 1 do
      post new_order_register_path
    end
    assert_redirected_to register_path(order_id: Order.last.id)
  end
end
