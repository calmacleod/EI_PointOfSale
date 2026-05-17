# frozen_string_literal: true

require "test_helper"

class AbilityTest < ActiveSupport::TestCase
  test "guest users cannot access authenticated resources" do
    ability = Ability.new(nil)

    assert_not ability.can?(:read, Product)
    assert_not ability.can?(:show, :register)
    assert_not ability.can?(:manage, Notification)
  end

  test "common users can use register and read catalog resources" do
    user = users(:one)
    ability = Ability.new(user)

    assert ability.can?(:show, :register)
    assert ability.can?(:new_order, :register)
    assert ability.can?(:read, Product)
    assert ability.can?(:read, Service)
    assert ability.can?(:read, Customer)
    assert ability.can?(:read, TaxCode)
    assert ability.can?(:receipt, Order)
  end

  test "common users cannot manage admin-only resources" do
    ability = Ability.new(users(:one))

    assert_not ability.can?(:manage, Product)
    assert_not ability.can?(:manage, Service)
    assert_not ability.can?(:manage, TaxCode)
    assert_not ability.can?(:manage, Discount)
    assert_not ability.can?(:read, OrderEvent)
  end

  test "users can only manage their own personal resources" do
    user = users(:one)
    other_user = users(:two)
    ability = Ability.new(user)

    assert ability.can?(:manage, Notification.new(user: user))
    assert_not ability.can?(:manage, Notification.new(user: other_user))
    assert ability.can?(:manage, SavedQuery.new(user: user))
    assert_not ability.can?(:manage, SavedQuery.new(user: other_user))
    assert ability.can?(:edit, user)
    assert_not ability.can?(:edit, other_user)
  end

  test "admins can manage admin resources and privileged order actions" do
    ability = Ability.new(users(:admin))

    assert ability.can?(:manage, Product)
    assert ability.can?(:manage, Service)
    assert ability.can?(:manage, TaxCode)
    assert ability.can?(:manage, Discount)
    assert ability.can?(:void, Order)
    assert ability.can?(:process_refund, Order)
    assert ability.can?(:read, OrderEvent)
  end
end
