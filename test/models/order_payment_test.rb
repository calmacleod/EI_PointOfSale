# frozen_string_literal: true

require "test_helper"

class OrderPaymentTest < ActiveSupport::TestCase
  test "validates amount is positive" do
    payment = OrderPayment.new(amount: 0, payment_method: :cash)
    assert_not payment.valid?
    assert_includes payment.errors[:amount], "must be greater than 0"
  end

  test "calculates change for cash payments" do
    payment = OrderPayment.new(
      order: orders(:draft_order),
      payment_method: :cash,
      amount: 15.00,
      amount_tendered: 20.00,
      received_by: users(:admin)
    )
    payment.valid?
    assert_equal 5.00, payment.change_given
  end

  test "does not calculate change for non-cash payments" do
    payment = OrderPayment.new(
      order: orders(:draft_order),
      payment_method: :debit,
      amount: 15.00,
      received_by: users(:admin)
    )
    payment.valid?
    assert_nil payment.change_given
  end

  test "rounds cash payment amount down to nearest 5 cents" do
    payment = OrderPayment.new(
      order: orders(:draft_order),
      payment_method: :cash,
      amount: 10.02,
      amount_tendered: 20.00,
      received_by: users(:admin)
    )
    payment.valid?
    assert_equal 10.00, payment.amount
    assert_equal 10.00, payment.change_given
  end

  test "rounds cash payment amount up to nearest 5 cents" do
    payment = OrderPayment.new(
      order: orders(:draft_order),
      payment_method: :cash,
      amount: 10.03,
      amount_tendered: 20.00,
      received_by: users(:admin)
    )
    payment.valid?
    assert_equal 10.05, payment.amount
    assert_equal 9.95, payment.change_given
  end

  test "does not round non-cash payment amount" do
    payment = OrderPayment.new(
      order: orders(:draft_order),
      payment_method: :debit,
      amount: 10.02,
      received_by: users(:admin)
    )
    payment.valid?
    assert_equal 10.02, payment.amount
  end

  test "display_method returns humanized method name" do
    payment = order_payments(:completed_cash_payment)
    assert_equal "Cash", payment.display_method
  end
end
