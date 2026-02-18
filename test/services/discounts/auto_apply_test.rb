# frozen_string_literal: true

require "test_helper"

module Discounts
  class AutoApplyTest < ActiveSupport::TestCase
    setup do
      @order = orders(:draft_order)
      @product = products(:dragon_shield_red)
      @other_product = products(:nhl_puck)  # not in any discount_items fixture
      @admin = users(:admin)
    end

    test "does nothing on a finalized order" do
      order = orders(:completed_order)
      assert_no_difference "OrderDiscount.count" do
        assert_no_difference "OrderLineDiscount.count" do
          AutoApply.call(order)
        end
      end
    end

    test "applies percentage_all discount to an nhl_puck line" do
      # nhl_puck is not in any specific discount_items, so only percentage_all (applies_to_all) matches
      @order.order_lines.create!(
        sellable: @other_product,
        name: @other_product.name,
        code: @other_product.code,
        quantity: 1,
        unit_price: @other_product.selling_price,
        line_total: @other_product.selling_price,
        position: 1
      )

      # Order-level discount created
      assert_difference "OrderDiscount.count", 1 do
        AutoApply.call(@order)
      end

      od = @order.order_discounts.last
      assert_equal discounts(:percentage_all).id, od.discount_id
      assert od.applies_to_all_items?
    end

    test "applies all matching discounts for dragon_shield_red" do
      # dragon_shield_red is in both fixed_total_specific and fixed_per_item_specific discount_items
      # percentage_all also applies → 1 order discount + 2 line discounts
      @order.order_lines.create!(
        sellable: @product,
        name: @product.name,
        code: @product.code,
        quantity: 1,
        unit_price: @product.selling_price,
        line_total: @product.selling_price,
        position: 1
      )

      # 1 order-level + 2 line-level discounts
      assert_difference "OrderDiscount.count", 1 do
        assert_difference "OrderLineDiscount.count", 2 do
          AutoApply.call(@order)
        end
      end

      applied_order_discount_ids = @order.order_discounts.pluck(:discount_id)
      applied_line_discount_ids = @order.order_line_discounts.pluck(:source_discount_id)

      assert_includes applied_order_discount_ids, discounts(:percentage_all).id
      assert_includes applied_line_discount_ids, discounts(:fixed_total_specific).id
      assert_includes applied_line_discount_ids, discounts(:fixed_per_item_specific).id
    end

    test "does not apply fixed_total_specific to a line for nhl_puck" do
      @order.order_lines.create!(
        sellable: @other_product,
        name: @other_product.name,
        code: @other_product.code,
        quantity: 1,
        unit_price: @other_product.selling_price,
        line_total: @other_product.selling_price,
        position: 1
      )

      AutoApply.call(@order)

      applied_line_discount_ids = @order.order_line_discounts.pluck(:source_discount_id)
      assert_not_includes applied_line_discount_ids, discounts(:fixed_total_specific).id
      assert_not_includes applied_line_discount_ids, discounts(:fixed_per_item_specific).id
    end

    test "applies specific-item discount when matching line exists" do
      discount = discounts(:fixed_total_specific)
      line = @order.order_lines.create!(
        sellable: @product,
        name: @product.name,
        code: @product.code,
        quantity: 1,
        unit_price: @product.selling_price,
        line_total: @product.selling_price,
        position: 1
      )

      AutoApply.call(@order)

      line_discount = line.order_line_discounts.find_by(source_discount: discount)
      assert_not_nil line_discount
      assert line_discount.auto_applied?
      assert line_discount.active?
    end

    test "excludes line discounts that are marked as fully excluded" do
      discount = discounts(:fixed_total_specific)
      line = @order.order_lines.create!(
        sellable: @product,
        name: @product.name,
        code: @product.code,
        quantity: 2,
        unit_price: @product.selling_price,
        line_total: @product.selling_price * 2,
        position: 1
      )

      # First apply the discount
      AutoApply.call(@order)
      line_discount = line.order_line_discounts.find_by(source_discount: discount)
      assert_not_nil line_discount
      assert line_discount.active?
      assert_equal 2, line_discount.applied_quantity

      # Exclude the discount from all units
      line_discount.exclude_all!

      # Re-applying should not restore it (user explicitly excluded all)
      AutoApply.call(@order)
      line_discount.reload
      assert line_discount.fully_excluded?
      assert_equal 0, line_discount.applied_quantity
    end

    test "partially excludes line discounts" do
      discount = discounts(:fixed_total_specific)
      line = @order.order_lines.create!(
        sellable: @product,
        name: @product.name,
        code: @product.code,
        quantity: 5,
        unit_price: @product.selling_price,
        line_total: @product.selling_price * 5,
        position: 1
      )

      # Apply the discount
      AutoApply.call(@order)
      line_discount = line.order_line_discounts.find_by(source_discount: discount)
      assert_not_nil line_discount
      assert_equal 5, line_discount.applied_quantity

      # Exclude discount from 2 units
      2.times { line_discount.exclude_one! }

      line_discount.reload
      assert_equal 3, line_discount.applied_quantity
      assert_equal 2, line_discount.excluded_quantity
      assert line_discount.active?
      assert_not line_discount.fully_excluded?
    end

    test "removes and re-adds auto-applied discounts on re-evaluation" do
      @order.order_lines.create!(
        sellable: @other_product,
        name: @other_product.name,
        code: @other_product.code,
        quantity: 1,
        unit_price: @other_product.selling_price,
        line_total: @other_product.selling_price,
        position: 1
      )

      AutoApply.call(@order)
      count_after_first = @order.order_discounts.where.not(discount_id: nil).count
      assert_equal 1, count_after_first

      # Calling again should keep same count (idempotent)
      AutoApply.call(@order)
      assert_equal count_after_first, @order.order_discounts.where.not(discount_id: nil).count
    end

    test "does not apply inactive discount" do
      # Only inactive_discount applies_to_all but is inactive
      # Disable percentage_all to isolate this test
      discounts(:percentage_all).update!(active: false)

      @order.order_lines.create!(
        sellable: @other_product,
        name: @other_product.name,
        code: @other_product.code,
        quantity: 1,
        unit_price: @other_product.selling_price,
        line_total: @other_product.selling_price,
        position: 1
      )

      assert_no_difference [ "OrderDiscount.count", "OrderLineDiscount.count" ] do
        AutoApply.call(@order)
      end
    end

    test "does not apply future discount" do
      discounts(:percentage_all).update!(active: false)

      @order.order_lines.create!(
        sellable: @other_product,
        name: @other_product.name,
        code: @other_product.code,
        quantity: 1,
        unit_price: @other_product.selling_price,
        line_total: @other_product.selling_price,
        position: 1
      )

      assert_no_difference [ "OrderDiscount.count", "OrderLineDiscount.count" ] do
        AutoApply.call(@order)
      end
    end

    test "removes line discounts when lines no longer qualify" do
      line = @order.order_lines.create!(
        sellable: @product,
        name: @product.name,
        code: @product.code,
        quantity: 1,
        unit_price: @product.selling_price,
        line_total: @product.selling_price,
        position: 1
      )

      AutoApply.call(@order)
      assert_equal 2, line.order_line_discounts.count

      # Remove product from discount items (simulate rule change)
      discount = discounts(:fixed_total_specific)
      discount.discount_items.destroy_all

      # Re-apply should remove the discount
      assert_difference "OrderLineDiscount.count", -1 do
        AutoApply.call(@order)
      end
    end
  end
end
