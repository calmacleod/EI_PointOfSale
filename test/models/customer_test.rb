# frozen_string_literal: true

require "test_helper"

class CustomerTest < ActiveSupport::TestCase
  test "valid with name" do
    customer = Customer.new(name: "Test Customer")
    assert customer.valid?
  end

  test "invalid without name" do
    customer = Customer.new(name: nil)
    assert_not customer.valid?
    assert_includes customer.errors[:name], "can't be blank"
  end

  test "member_number uniqueness" do
    existing = customers(:acme_corp)
    customer = Customer.new(name: "Other", member_number: existing.member_number)
    assert_not customer.valid?
    assert_includes customer.errors[:member_number], "has already been taken"
  end

  test "member_number allows nil" do
    customer = Customer.new(name: "No Member #", member_number: nil)
    assert customer.valid?
  end

  test "address returns formatted string" do
    customer = customers(:acme_corp)
    assert_includes customer.address, "123 Main St"
    assert_includes customer.address, "Springfield"
    assert_includes customer.address, "ON"
  end

  test "address returns empty when no components" do
    customer = customers(:jane_doe)
    assert_equal "", customer.address
  end

  test "discards" do
    customer = customers(:acme_corp)
    customer.discard
    assert customer.discarded?
  end
end
