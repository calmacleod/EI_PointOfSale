# frozen_string_literal: true

require "test_helper"

class RefundTest < ActiveSupport::TestCase
  test "generates refund number on create" do
    refund = Refund.create!(
      order: orders(:completed_order),
      refund_type: :full,
      total: 33.88,
      processed_by: users(:admin)
    )
    assert_match(/\AREF-\d{6}\z/, refund.refund_number)
  end

  test "prevents update after creation" do
    refund = Refund.create!(
      order: orders(:completed_order),
      refund_type: :full,
      total: 33.88,
      processed_by: users(:admin)
    )
    assert_raises(ActiveRecord::ReadOnlyRecord) do
      refund.update!(reason: "changed my mind")
    end
  end

  test "prevents destroy" do
    refund = Refund.create!(
      order: orders(:completed_order),
      refund_type: :full,
      total: 33.88,
      processed_by: users(:admin)
    )
    assert_raises(ActiveRecord::ReadOnlyRecord) do
      refund.destroy!
    end
  end

  test "validates total is positive" do
    refund = Refund.new(total: 0)
    assert_not refund.valid?
    assert_includes refund.errors[:total], "must be greater than 0"
  end
end
