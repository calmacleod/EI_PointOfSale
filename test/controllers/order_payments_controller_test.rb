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

  test "POST creates a debit payment" do
    assert_difference "OrderPayment.count", 1 do
      post order_order_payments_path(@order), params: {
        order_payment: { payment_method: "debit", amount: 20.00 }
      }, headers: TURBO_HEADERS
    end
    assert_response :success
    assert_equal "debit", OrderPayment.last.payment_method
  end

  test "POST creates a credit payment" do
    assert_difference "OrderPayment.count", 1 do
      post order_order_payments_path(@order), params: {
        order_payment: { payment_method: "credit", amount: 20.00 }
      }, headers: TURBO_HEADERS
    end
    assert_response :success
    assert_equal "credit", OrderPayment.last.payment_method
  end

  test "POST replaces payment panel Turbo targets on success" do
    post order_order_payments_path(@order), params: {
      order_payment: { payment_method: "debit", amount: 15.00 }
    }, headers: TURBO_HEADERS
    assert_response :success
    assert_turbo_stream_replaces(*PAYMENT_PANELS)
  end

  test "DELETE replaces payment panel Turbo targets" do
    payment = @order.order_payments.create!(
      payment_method: :debit, amount: 10.00, received_by: @admin
    )
    delete order_payment_path(payment), headers: TURBO_HEADERS
    assert_response :success
    assert_turbo_stream_replaces(*PAYMENT_PANELS)
  end

  test "POST gift_certificate payment decrements GC balance" do
    gc = gift_certificates(:active_gc)
    initial_balance = gc.remaining_balance

    assert_difference "OrderPayment.count", 1 do
      post order_order_payments_path(@order), params: {
        order_payment: {
          payment_method: "gift_certificate",
          amount: 20.00,
          reference: gc.code
        }
      }, headers: TURBO_HEADERS
    end
    assert_response :success
    assert_equal initial_balance - 20.00, gc.reload.remaining_balance
  end

  test "POST gift_certificate payment fails for exhausted GC" do
    gc = gift_certificates(:exhausted_gc)

    assert_no_difference "OrderPayment.count" do
      post order_order_payments_path(@order), params: {
        order_payment: {
          payment_method: "gift_certificate",
          amount: 10.00,
          reference: gc.code
        }
      }, headers: TURBO_HEADERS
    end
    assert_response :success
    assert_match /not found or not active/, response.body
  end

  test "POST gift_certificate payment fails for unknown code" do
    assert_no_difference "OrderPayment.count" do
      post order_order_payments_path(@order), params: {
        order_payment: {
          payment_method: "gift_certificate",
          amount: 10.00,
          reference: "GC-DOESNOTEXIST"
        }
      }, headers: TURBO_HEADERS
    end
    assert_response :success
    assert_match /not found or not active/, response.body
  end

  test "DELETE gift_certificate payment restores GC balance" do
    gc = gift_certificates(:active_gc)
    payment = @order.order_payments.create!(
      payment_method: :gift_certificate,
      amount: 20.00,
      received_by: @admin,
      gift_certificate: gc
    )
    gc.update!(remaining_balance: gc.remaining_balance - 20.00)
    balance_after_payment = gc.remaining_balance

    delete order_payment_path(payment), headers: TURBO_HEADERS

    assert gc.reload.remaining_balance > balance_after_payment
  end

  test "split tender allows two payments on same order" do
    assert_difference "OrderPayment.count", 2 do
      post order_order_payments_path(@order), params: {
        order_payment: { payment_method: "cash", amount: 10.00, amount_tendered: 10.00 }
      }, headers: TURBO_HEADERS

      post order_order_payments_path(@order), params: {
        order_payment: { payment_method: "debit", amount: 10.00 }
      }, headers: TURBO_HEADERS
    end
    assert_equal 2, @order.order_payments.reload.count
  end
end
