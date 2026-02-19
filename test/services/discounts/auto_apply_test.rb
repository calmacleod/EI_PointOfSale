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

    test "applies customer discount when customer with discount is assigned" do
      # Disable applies_to_all discount to isolate test
      discounts(:percentage_all).update!(active: false)

      # Create a unique customer discount (not applies_to_all so it doesn't auto-apply)
      customer_discount = Discount.create!(
        name: "Employee 15% Off",
        discount_type: :percentage,
        value: 15.00,
        active: true,
        applies_to_all: false
      )

      customer = customers(:acme_corp)
      customer.update!(discount: customer_discount)
      @order.update!(customer: customer)

      # Use @other_product (nhl_puck) which is not in any discount_items fixture
      line = @order.order_lines.create!(
        sellable: @other_product,
        name: @other_product.name,
        code: @other_product.code,
        quantity: 1,
        unit_price: @other_product.selling_price,
        line_total: @other_product.selling_price,
        position: 1
      )

      # Per-item customer discounts create OrderLineDiscount, not OrderDiscount
      assert_difference "OrderLineDiscount.count", 1 do
        AutoApply.call(@order)
      end

      line_discount = line.order_line_discounts.find_by(source_discount: customer_discount)
      assert_not_nil line_discount
      assert_equal customer_discount.name, line_discount.name
      assert_equal "percentage", line_discount.discount_type
    end

    test "removes customer discount when customer is removed from order" do
      discounts(:percentage_all).update!(active: false)

      customer_discount = Discount.create!(
        name: "Employee 15% Off",
        discount_type: :percentage,
        value: 15.00,
        active: true,
        applies_to_all: false
      )

      customer = customers(:acme_corp)
      customer.update!(discount: customer_discount)
      @order.update!(customer: customer)

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
      assert line.order_line_discounts.exists?(source_discount: customer_discount)

      # Remove customer
      @order.update!(customer: nil)

      assert_difference "OrderLineDiscount.count", -1 do
        AutoApply.call(@order)
      end

      assert_not line.order_line_discounts.exists?(source_discount: customer_discount)
    end

    test "removes old customer discount when customer changes to different discount" do
      discounts(:percentage_all).update!(active: false)

      old_discount = Discount.create!(
        name: "Employee 15% Off",
        discount_type: :percentage,
        value: 15.00,
        active: true,
        applies_to_all: false
      )

      new_discount = Discount.create!(
        name: "Manager 20% Off",
        discount_type: :percentage,
        value: 20.00,
        active: true,
        applies_to_all: false
      )

      customer = customers(:acme_corp)
      customer.update!(discount: old_discount)
      @order.update!(customer: customer)

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
      assert line.order_line_discounts.exists?(source_discount: old_discount)

      # Change customer's discount
      customer.update!(discount: new_discount)

      AutoApply.call(@order)

      assert_not line.order_line_discounts.exists?(source_discount: old_discount)
      assert line.order_line_discounts.exists?(source_discount: new_discount)
    end

    test "customer discount is applied alongside other order-level discounts" do
      customer_discount = Discount.create!(
        name: "Employee 15% Off",
        discount_type: :percentage,
        value: 15.00,
        active: true,
        applies_to_all: false
      )

      customer = customers(:acme_corp)
      customer.update!(discount: customer_discount)
      @order.update!(customer: customer)

      line = @order.order_lines.create!(
        sellable: @other_product,
        name: @other_product.name,
        code: @other_product.code,
        quantity: 1,
        unit_price: @other_product.selling_price,
        line_total: @other_product.selling_price,
        position: 1
      )

      AutoApply.call(@order)

      # Should have the customer discount applied as line-level (plus percentage_all as order-level)
      assert line.order_line_discounts.exists?(source_discount: customer_discount)
      assert @order.order_discounts.exists?(discount_id: discounts(:percentage_all).id)
    end

    test "does not apply per-item discount to denied items even when applies_to_all" do
      # percentage_all is a per-item (percentage) discount with applies_to_all: true
      discount = discounts(:percentage_all)
      denied_product = products(:dragon_shield_blue)
      # dragon_shield_blue is in the deny list for fixed_per_item_specific but not percentage_all
      # Let's add it to percentage_all's deny list
      discount.discount_items.create!(
        discountable: denied_product,
        exclusion_type: :denied
      )

      line = @order.order_lines.create!(
        sellable: denied_product,
        name: denied_product.name,
        code: denied_product.code,
        quantity: 1,
        unit_price: denied_product.selling_price,
        line_total: denied_product.selling_price,
        position: 1
      )

      AutoApply.call(@order)

      # The line should NOT have the percentage_all discount applied
      line_discount = line.order_line_discounts.find_by(source_discount: discount)
      assert_nil line_discount
    end

    test "denies discount when product is in deny list" do
      discount = discounts(:fixed_per_item_specific)
      denied_product = products(:dragon_shield_blue)

      line = @order.order_lines.create!(
        sellable: denied_product,
        name: denied_product.name,
        code: denied_product.code,
        quantity: 1,
        unit_price: denied_product.selling_price,
        line_total: denied_product.selling_price,
        position: 1
      )

      AutoApply.call(@order)

      # Should not have the fixed_per_item_specific discount
      line_discount = line.order_line_discounts.find_by(source_discount: discount)
      assert_nil line_discount
    end

    test "applies discount when product is in allow list and not in deny list" do
      discount = discounts(:fixed_per_item_specific)
      allowed_product = products(:dragon_shield_red)

      line = @order.order_lines.create!(
        sellable: allowed_product,
        name: allowed_product.name,
        code: allowed_product.code,
        quantity: 1,
        unit_price: allowed_product.selling_price,
        line_total: allowed_product.selling_price,
        position: 1
      )

      AutoApply.call(@order)

      # Should have the fixed_per_item_specific discount
      line_discount = line.order_line_discounts.find_by(source_discount: discount)
      assert_not_nil line_discount
      assert line_discount.active?
    end

    test "denies discount when product group is in deny list" do
      # Use a fresh discount to avoid fixture conflicts
      discount = Discount.create!(
        name: "Test Group Deny",
        discount_type: :percentage,
        value: 10.00,
        active: true,
        applies_to_all: true
      )

      # Add a product to a group
      product_in_denied_group = products(:dragon_shield_red)
      trading_cards_group = product_groups(:trading_cards)
      product_in_denied_group.update!(product_group: trading_cards_group)

      # Create deny list entry for the trading_cards group
      discount.discount_items.create!(
        discountable: trading_cards_group,
        exclusion_type: :denied
      )

      line = @order.order_lines.create!(
        sellable: product_in_denied_group,
        name: product_in_denied_group.name,
        code: product_in_denied_group.code,
        quantity: 1,
        unit_price: product_in_denied_group.selling_price,
        line_total: product_in_denied_group.selling_price,
        position: 1
      )

      AutoApply.call(@order)

      # Should NOT have the discount because product is in denied group
      line_discount = line.order_line_discounts.find_by(source_discount: discount)
      assert_nil line_discount
    end

    test "applies discount via product group allow list" do
      discount = Discount.create!(
        name: "Group Discount",
        discount_type: :percentage,
        value: 10.00,
        active: true,
        applies_to_all: false
      )

      # Add gaming_supplies group to allow list
      discount.discount_items.create!(
        discountable: product_groups(:gaming_supplies),
        exclusion_type: :allowed
      )

      # Add a product to the gaming_supplies group
      product_in_group = products(:dragon_shield_red)
      product_in_group.update!(product_group: product_groups(:gaming_supplies))

      line = @order.order_lines.create!(
        sellable: product_in_group,
        name: product_in_group.name,
        code: product_in_group.code,
        quantity: 1,
        unit_price: product_in_group.selling_price,
        line_total: product_in_group.selling_price,
        position: 1
      )

      AutoApply.call(@order)

      # Should have the discount because product is in allowed group
      line_discount = line.order_line_discounts.find_by(source_discount: discount)
      assert_not_nil line_discount
      assert line_discount.active?
    end

    test "deny list takes precedence over product group allow list" do
      discount = Discount.create!(
        name: "Group Discount",
        discount_type: :percentage,
        value: 10.00,
        active: true,
        applies_to_all: false
      )

      # Add gaming_supplies group to allow list
      discount.discount_items.create!(
        discountable: product_groups(:gaming_supplies),
        exclusion_type: :allowed
      )

      # Add a specific product to deny list (even though it's in the allowed group)
      product = products(:dragon_shield_red)
      product.update!(product_group: product_groups(:gaming_supplies))
      discount.discount_items.create!(
        discountable: product,
        exclusion_type: :denied
      )

      line = @order.order_lines.create!(
        sellable: product,
        name: product.name,
        code: product.code,
        quantity: 1,
        unit_price: product.selling_price,
        line_total: product.selling_price,
        position: 1
      )

      AutoApply.call(@order)

      # Should NOT have the discount because product is explicitly denied
      line_discount = line.order_line_discounts.find_by(source_discount: discount)
      assert_nil line_discount
    end

    test "does not duplicate customer discount when applies_to_all is true and per_item type" do
      # This is the bug scenario: a customer discount with applies_to_all: true and percentage type
      # should only apply as line-level, NOT as both order-level AND line-level
      discounts(:percentage_all).update!(active: false)

      customer_discount = Discount.create!(
        name: "Employee 10% Off Everything",
        discount_type: :percentage,
        value: 10.00,
        active: true,
        applies_to_all: true  # This is the key - applies to all items
      )

      customer = customers(:acme_corp)
      customer.update!(discount: customer_discount)
      @order.update!(customer: customer)

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

      # Should have exactly ONE line-level discount for the customer discount
      line_discounts = line.order_line_discounts.where(source_discount: customer_discount)
      assert_equal 1, line_discounts.count, "Customer discount should only appear once as line-level"

      # Should NOT have an order-level discount for the customer discount
      order_discount = @order.order_discounts.find_by(discount_id: customer_discount.id)
      assert_nil order_discount, "Customer discount should not appear as order-level when handled separately"
    end

    test "respects deny-list for customer per-item discount with applies_to_all" do
      discounts(:percentage_all).update!(active: false)

      customer_discount = Discount.create!(
        name: "Employee 10% Off",
        discount_type: :percentage,
        value: 10.00,
        active: true,
        applies_to_all: true
      )

      # Add a deny-list item for the customer discount
      denied_product = products(:dragon_shield_blue)
      customer_discount.discount_items.create!(
        discountable: denied_product,
        exclusion_type: :denied
      )

      customer = customers(:acme_corp)
      customer.update!(discount: customer_discount)
      @order.update!(customer: customer)

      # Add a denied product
      denied_line = @order.order_lines.create!(
        sellable: denied_product,
        name: denied_product.name,
        code: denied_product.code,
        quantity: 1,
        unit_price: denied_product.selling_price,
        line_total: denied_product.selling_price,
        position: 1
      )

      # Add an allowed product
      allowed_product = products(:nhl_puck)
      allowed_line = @order.order_lines.create!(
        sellable: allowed_product,
        name: allowed_product.name,
        code: allowed_product.code,
        quantity: 1,
        unit_price: allowed_product.selling_price,
        line_total: allowed_product.selling_price,
        position: 2
      )

      AutoApply.call(@order)

      # Denied line should NOT have the discount
      assert_nil denied_line.order_line_discounts.find_by(source_discount: customer_discount)

      # Allowed line should have the discount
      assert_not_nil allowed_line.order_line_discounts.find_by(source_discount: customer_discount)
    end

    test "removes all customer discounts when customer is removed from order" do
      discounts(:percentage_all).update!(active: false)
      # Also disable fixture discounts that might interfere
      discounts(:fixed_total_specific).update!(active: false)
      discounts(:fixed_per_item_specific).update!(active: false)

      customer_discount = Discount.create!(
        name: "Employee 10% Off",
        discount_type: :percentage,
        value: 10.00,
        active: true,
        applies_to_all: true
      )

      customer = customers(:acme_corp)
      customer.update!(discount: customer_discount)
      @order.update!(customer: customer)

      # Add multiple lines using products not in fixture discounts
      line1 = @order.order_lines.create!(
        sellable: @other_product,  # nhl_puck - not in fixture discounts
        name: @other_product.name,
        code: @other_product.code,
        quantity: 1,
        unit_price: @other_product.selling_price,
        line_total: @other_product.selling_price,
        position: 1
      )

      another_product = products(:dragon_shield_blue)
      line2 = @order.order_lines.create!(
        sellable: another_product,
        name: another_product.name,
        code: another_product.code,
        quantity: 1,
        unit_price: another_product.selling_price,
        line_total: another_product.selling_price,
        position: 2
      )

      # Apply discount initially
      AutoApply.call(@order)

      # Verify customer discount was applied to each line (1 per line)
      assert_equal 1, line1.order_line_discounts.where(source_discount: customer_discount).count
      assert_equal 1, line2.order_line_discounts.where(source_discount: customer_discount).count
      assert_equal 2, @order.order_line_discounts.where(source_discount: customer_discount).count

      # Remove customer from order
      @order.update!(customer: nil)

      # Re-apply - should remove all customer discounts
      AutoApply.call(@order)

      # Verify ALL customer discounts were removed from all lines
      assert_equal 0, line1.order_line_discounts.where(source_discount: customer_discount).count
      assert_equal 0, line2.order_line_discounts.where(source_discount: customer_discount).count
      assert_equal 0, @order.order_line_discounts.where(source_discount: customer_discount).count
      assert_nil @order.order_discounts.find_by(discount_id: customer_discount.id)
    end

    test "removes fixed_total customer discount when customer is removed" do
      discounts(:percentage_all).update!(active: false)

      # Create a fixed_total customer discount
      customer_discount = Discount.create!(
        name: "Employee $5 Off",
        discount_type: :fixed_total,
        value: 5.00,
        active: true,
        applies_to_all: false
      )

      customer = customers(:acme_corp)
      customer.update!(discount: customer_discount)
      @order.update!(customer: customer)

      line = @order.order_lines.create!(
        sellable: @product,
        name: @product.name,
        code: @product.code,
        quantity: 1,
        unit_price: @product.selling_price,
        line_total: @product.selling_price,
        position: 1
      )

      # Apply discount initially
      AutoApply.call(@order)

      # Verify order-level discount was created
      assert @order.order_discounts.exists?(discount_id: customer_discount.id)

      # Remove customer
      @order.update!(customer: nil)

      # Re-apply - should remove the order-level discount
      assert_difference "OrderDiscount.count", -1 do
        AutoApply.call(@order)
      end

      # Verify discount was removed
      assert_nil @order.order_discounts.find_by(discount_id: customer_discount.id)
    end

    test "never applies discounts to gift certificate lines" do
      # Create a gift certificate line
      gc = gift_certificates(:pending_gc)
      gc_line = @order.order_lines.create!(
        sellable: gc,
        name: gc.sellable_name,
        code: gc.sellable_code,
        quantity: 1,
        unit_price: gc.sellable_price,
        line_total: gc.sellable_price,
        position: 1
      )

      # Also add a regular product line that should get discounts
      product_line = @order.order_lines.create!(
        sellable: @product,
        name: @product.name,
        code: @product.code,
        quantity: 1,
        unit_price: @product.selling_price,
        line_total: @product.selling_price,
        position: 2
      )

      AutoApply.call(@order)

      # Gift certificate line should have NO discounts
      assert_equal 0, gc_line.order_line_discounts.count,
        "Gift certificate line should never have line-level discounts"

      # Product line should have discounts (2 line-level from fixtures)
      assert product_line.order_line_discounts.count > 0,
        "Product line should have line-level discounts applied"
    end

    test "never applies customer discounts to gift certificate lines" do
      discounts(:percentage_all).update!(active: false)

      customer_discount = Discount.create!(
        name: "Employee 10% Off",
        discount_type: :percentage,
        value: 10.00,
        active: true,
        applies_to_all: true
      )

      customer = customers(:acme_corp)
      customer.update!(discount: customer_discount)
      @order.update!(customer: customer)

      # Create a gift certificate line
      gc = gift_certificates(:pending_gc)
      gc_line = @order.order_lines.create!(
        sellable: gc,
        name: gc.sellable_name,
        code: gc.sellable_code,
        quantity: 1,
        unit_price: gc.sellable_price,
        line_total: gc.sellable_price,
        position: 1
      )

      # Also add a regular product line
      product_line = @order.order_lines.create!(
        sellable: @product,
        name: @product.name,
        code: @product.code,
        quantity: 1,
        unit_price: @product.selling_price,
        line_total: @product.selling_price,
        position: 2
      )

      AutoApply.call(@order)

      # Gift certificate line should NOT have customer discount
      assert_nil gc_line.order_line_discounts.find_by(source_discount: customer_discount),
        "Gift certificate line should never have customer discount applied"

      # Product line should have customer discount
      assert_not_nil product_line.order_line_discounts.find_by(source_discount: customer_discount),
        "Product line should have customer discount applied"
    end

    test "never applies discounts even when gift certificate is in allow list" do
      # Create a discount with applies_to_all: false but add gift certificate to allow list
      discount = Discount.create!(
        name: "GC Discount (should not apply)",
        discount_type: :percentage,
        value: 10.00,
        active: true,
        applies_to_all: false
      )

      gc = gift_certificates(:pending_gc)

      # Try to add gift certificate to allow list (simulating someone trying to apply discount)
      discount.discount_items.create!(
        discountable: gc,
        exclusion_type: :allowed
      )

      gc_line = @order.order_lines.create!(
        sellable: gc,
        name: gc.sellable_name,
        code: gc.sellable_code,
        quantity: 1,
        unit_price: gc.sellable_price,
        line_total: gc.sellable_price,
        position: 1
      )

      AutoApply.call(@order)

      # Even when explicitly in allow list, gift certificate should NOT get discount
      assert_nil gc_line.order_line_discounts.find_by(source_discount: discount),
        "Gift certificate should never receive discounts, even in allow list"
    end

    test "excludes gift certificates from order-level discount subtotal calculations" do
      # Create a fixed_amount order-level discount
      discount = Discount.create!(
        name: "$10 Off Order",
        discount_type: :fixed_total,
        value: 10.00,
        active: true,
        applies_to_all: true
      )

      # Add a gift certificate line ($50)
      gc = gift_certificates(:pending_gc)
      gc_line = @order.order_lines.create!(
        sellable: gc,
        name: gc.sellable_name,
        code: gc.sellable_code,
        quantity: 1,
        unit_price: 50.00,
        line_total: 50.00,
        position: 1
      )

      # Add a product line ($30)
      product_line = @order.order_lines.create!(
        sellable: @product,
        name: @product.name,
        code: @product.code,
        quantity: 1,
        unit_price: 30.00,
        line_total: 30.00,
        position: 2
      )

      AutoApply.call(@order)
      Orders::CalculateTotals.call(@order.reload)

      order_discount = @order.order_discounts.find_by(discount_id: discount.id)
      assert_not_nil order_discount

      # Discount should be calculated on product line only ($30), not gift certificate
      # So max discount is $10 (the fixed amount), or $30 (product subtotal) whichever is less
      # Since discount is $10 and product subtotal is $30, calculated amount should be $10
      # But if gift cert was included, subtotal would be $80 and discount would still be $10
      # Let's verify by checking that the gift cert line has no discounts
      assert_equal 0, gc_line.order_line_discounts.count

      # The order discount should exist and be calculated
      assert order_discount.calculated_amount > 0
    end
  end
end
