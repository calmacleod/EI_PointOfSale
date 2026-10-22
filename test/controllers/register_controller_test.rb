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
    assert_equal "register", inertia_props["view"]
    assert_equal order.number, inertia_props.dig("order", "number")
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

  test "lookup is available to cashiers and searches only the sellable catalog" do
    sign_in_as(users(:one))
    get lookup_register_path, params: { q: "Dragon" }, as: :json
    assert_response :success
    assert response.parsed_body.fetch("results").any?
    assert response.parsed_body.fetch("results").all? { |item| %w[Product Service].include?(item.fetch("type")) }
  end

  test "JSON scans return the updated cart directly and increment an existing line" do
    order = orders(:draft_order)
    Discount.update_all(active: false)
    2.times do
      post quick_lookup_orders_path, params: { order_id: order.id, code: "ds-mat-red" }, as: :json
      assert_response :success
    end
    cart = response.parsed_body.fetch("order")
    assert_equal 1, cart.fetch("lines").size
    assert_equal 2, cart.fetch("lines").first.fetch("quantity")
    assert_equal "$33.88", cart.fetch("total")
    assert_equal "$33.88", cart.fetch("balance_due")
  end

  test "selected items use their type and id and current price including services without a code" do
    service = Service.create!(name: "Uncoded service", price: 11)
    service.update!(price: 17)
    post quick_lookup_orders_path, params: { order_id: orders(:draft_order).id, sellable_id: service.id, sellable_type: "Service" }, as: :json
    assert_response :success
    line = response.parsed_body.dig("order", "lines").last
    assert_equal "Uncoded service", line.fetch("name")
    assert_equal "$17.00", line.fetch("unit_price")
  end

  test "failed JSON scans and invalid types do not add items" do
    [ { code: "NOT-A-CODE" }, { sellable_id: users(:admin).id, sellable_type: "User" } ].each do |lookup|
      assert_no_difference "OrderLine.count" do
        post quick_lookup_orders_path, params: lookup.merge(order_id: orders(:draft_order).id), as: :json
      end
      assert_response :unprocessable_entity
      assert response.parsed_body.fetch("error").present?
    end
  end

  test "scans cannot modify held or finalized orders" do
    %i[held_order completed_order].each do |fixture|
      assert_no_difference "OrderLine.count" do
        post quick_lookup_orders_path, params: { order_id: orders(fixture).id, code: "DS-MAT-RED" }, as: :json
      end
      assert_response :unprocessable_entity
    end
  end
end
