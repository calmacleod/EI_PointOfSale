# frozen_string_literal: true

require "test_helper"

class OrderPaymentsControllerTest < ActionDispatch::IntegrationTest
  setup do
    @admin = users(:admin)
    sign_in_as(@admin)
    @order = orders(:draft_order)
  end

  test "POST /orders/:id/order_payments creates a payment" do
    assert_difference "OrderPayment.count", 1 do
      post order_order_payments_path(@order), params: {
        order_payment: { payment_method: "cash", amount: 20.00, amount_tendered: 25.00 }
      }, headers: { "Accept" => "text/vnd.turbo-stream.html" }
    end
    assert_response :success
  end

  test "POST creates partial payment with exact amount submitted" do
    # held_order has a total of 16.94
    held = orders(:held_order)

    assert_difference "OrderPayment.count", 1 do
      post order_order_payments_path(held), params: {
        order_payment: { payment_method: "cash", amount: 10.00, amount_tendered: 10.00 }
      }, headers: { "Accept" => "text/vnd.turbo-stream.html" }
    end

    assert_response :success
    payment = OrderPayment.last
    assert_equal 10.00, payment.amount
    assert_equal "cash", payment.payment_method
  end

  test "DELETE /order_payments/:id removes a payment" do
    payment = @order.order_payments.create!(
      payment_method: :debit, amount: 10.00, received_by: @admin
    )

    assert_difference "OrderPayment.count", -1 do
      delete order_payment_path(payment),
             headers: { "Accept" => "text/vnd.turbo-stream.html" }
    end
    assert_response :success
  end

  test "POST rejects cash payment when tendered is less than amount" do
    held = orders(:held_order)

    assert_no_difference "OrderPayment.count" do
      post order_order_payments_path(held), params: {
        order_payment: { payment_method: "cash", amount: 15.00, amount_tendered: 10.00 }
      }, headers: { "Accept" => "text/vnd.turbo-stream.html" }
    end

    assert_response :success
    assert_match /must be at least/, response.body
  end
end
