# frozen_string_literal: true

require "test_helper"

class GiftCertificateTest < ActiveSupport::TestCase
  test "generates a code on create if none provided" do
    gc = GiftCertificate.create!(initial_amount: 50.00, issued_by: users(:admin))
    assert gc.code.starts_with?("GC-")
    assert_equal 11, gc.code.length  # "GC-" + 8 chars
  end

  test "sets remaining_balance to initial_amount on create" do
    gc = GiftCertificate.create!(initial_amount: 75.00, issued_by: users(:admin))
    assert_equal 75.00, gc.remaining_balance
  end

  test "starts as pending status" do
    gc = GiftCertificate.new(initial_amount: 50.00, issued_by: users(:admin))
    assert gc.pending?
  end

  test "validates initial_amount must be positive" do
    gc = GiftCertificate.new(initial_amount: 0, issued_by: users(:admin))
    assert_not gc.valid?
    assert_includes gc.errors[:initial_amount], "must be greater than 0"
  end

  test "validates remaining_balance must be >= 0" do
    gc = GiftCertificate.new(initial_amount: 50.00, remaining_balance: -1, issued_by: users(:admin))
    gc.code = "GC-TEST1234"
    assert_not gc.valid?
    assert_includes gc.errors[:remaining_balance], "must be greater than or equal to 0"
  end

  test "validates code uniqueness" do
    gc = GiftCertificate.new(initial_amount: 50.00, code: gift_certificates(:active_gc).code, issued_by: users(:admin))
    assert_not gc.valid?
    assert_includes gc.errors[:code], "has already been taken"
  end

  test "sellable_tax_exempt? returns true" do
    gc = gift_certificates(:active_gc)
    assert gc.sellable_tax_exempt?
  end

  test "sellable_price returns initial_amount" do
    gc = gift_certificates(:active_gc)
    assert_equal gc.initial_amount, gc.sellable_price
  end

  test "sellable_name includes code" do
    gc = gift_certificates(:active_gc)
    assert_equal "Gift Certificate (#{gc.code})", gc.sellable_name
  end

  test "find_redeemable returns active gc with balance" do
    gc = gift_certificates(:active_gc)
    assert_equal gc, GiftCertificate.find_redeemable(gc.code)
  end

  test "find_redeemable returns nil for exhausted gc" do
    gc = gift_certificates(:exhausted_gc)
    assert_nil GiftCertificate.find_redeemable(gc.code)
  end

  test "find_redeemable returns nil for unknown code" do
    assert_nil GiftCertificate.find_redeemable("GC-NOTEXIST")
  end

  test "find_redeemable is case-insensitive" do
    gc = gift_certificates(:active_gc)
    assert_equal gc, GiftCertificate.find_redeemable(gc.code.downcase)
  end

  test "redeemable? returns true for active gc with balance" do
    gc = gift_certificates(:active_gc)
    assert gc.redeemable?
  end

  test "redeemable? returns false for exhausted gc" do
    gc = gift_certificates(:exhausted_gc)
    assert_not gc.redeemable?
  end

  test "decrement_balance! reduces remaining_balance" do
    gc = gift_certificates(:active_gc)
    original = gc.remaining_balance
    gc.decrement_balance!(10.00)
    assert_equal (original - 10.00).round(2), gc.reload.remaining_balance
  end

  test "decrement_balance! sets status to exhausted when balance reaches zero" do
    gc = gift_certificates(:active_gc)
    gc.decrement_balance!(gc.remaining_balance)
    assert gc.reload.exhausted?
    assert_equal 0, gc.remaining_balance
  end

  test "decrement_balance! raises on insufficient balance" do
    gc = gift_certificates(:active_gc)
    assert_raises(ArgumentError) { gc.decrement_balance!(gc.remaining_balance + 1) }
  end

  test "increment_balance! increases remaining_balance" do
    gc = gift_certificates(:exhausted_gc)
    gc.increment_balance!(10.00)
    gc.reload
    assert_equal 10.00, gc.remaining_balance
    assert gc.active?
  end

  test "increment_balance! caps at initial_amount" do
    gc = gift_certificates(:active_gc)
    gc.increment_balance!(1000.00)
    assert_equal gc.initial_amount, gc.reload.remaining_balance
  end
end
