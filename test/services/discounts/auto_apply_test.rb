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
        AutoApply.call(order)
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

      assert_difference "OrderDiscount.count", 1 do
        AutoApply.call(@order)
      end

      od = @order.order_discounts.last
      assert_equal discounts(:percentage_all).id, od.discount_id
      assert od.applies_to_all_items?
    end

    test "applies all matching discounts for dragon_shield_red" do
      # dragon_shield_red is in both fixed_total_specific and fixed_per_item_specific discount_items
      # percentage_all also applies → 3 discounts total
      @order.order_lines.create!(
        sellable: @product,
        name: @product.name,
        code: @product.code,
        quantity: 1,
        unit_price: @product.selling_price,
        line_total: @product.selling_price,
        position: 1
      )

      assert_difference "OrderDiscount.count", 3 do
        AutoApply.call(@order)
      end

      applied_discount_ids = @order.order_discounts.pluck(:discount_id)
      assert_includes applied_discount_ids, discounts(:percentage_all).id
      assert_includes applied_discount_ids, discounts(:fixed_total_specific).id
      assert_includes applied_discount_ids, discounts(:fixed_per_item_specific).id
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

      applied_discount_ids = @order.order_discounts.pluck(:discount_id)
      assert_not_includes applied_discount_ids, discounts(:fixed_total_specific).id
      assert_not_includes applied_discount_ids, discounts(:fixed_per_item_specific).id
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

      od = @order.order_discounts.find_by(discount_id: discount.id)
      assert_not_nil od
      assert od.applies_to_specific_items?
      assert_includes od.order_lines, line
    end

    test "skips discounts in overridden_discount_ids" do
      skip_discount = discounts(:percentage_all)
      @order.update_column(:metadata, { "overridden_discount_ids" => [ skip_discount.id ] })

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

      applied_discount_ids = @order.order_discounts.pluck(:discount_id)
      assert_not_includes applied_discount_ids, skip_discount.id
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

      # Calling again should remove and recreate (same count)
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

      assert_no_difference "OrderDiscount.count" do
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

      assert_no_difference "OrderDiscount.count" do
        AutoApply.call(@order)
      end
    end
  end
end
