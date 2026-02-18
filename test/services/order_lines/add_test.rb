# frozen_string_literal: true

require "test_helper"

module OrderLines
  class AddTest < ActiveSupport::TestCase
    setup do
      @order = orders(:draft_order)
      @product = products(:dragon_shield_red)
      @service = services(:printer_refill)
      @admin = users(:admin)
    end

    test "creates a new line when sellable is not in order" do
      assert_difference "OrderLine.count", 1 do
        result = Add.call(order: @order, sellable: @product, actor: @admin)
        assert result.success?
        assert_equal :created, result.action
      end

      line = @order.order_lines.last
      assert_equal @product, line.sellable
      assert_equal 1, line.quantity
      assert_equal @product.sellable_name, line.name
      assert_equal @product.sellable_code, line.code
    end

    test "increments existing line quantity when increment_if_exists is true" do
      # First, add the product
      Add.call(order: @order, sellable: @product, actor: @admin)
      first_line = @order.order_lines.last

      # Add again with increment_if_exists
      assert_no_difference "OrderLine.count" do
        result = Add.call(order: @order, sellable: @product, actor: @admin, increment_if_exists: true)
        assert result.success?
        assert_equal :incremented, result.action
      end

      assert_equal 2, first_line.reload.quantity
    end

    test "creates new line when increment_if_exists is false" do
      # First, add the product
      Add.call(order: @order, sellable: @product, actor: @admin)

      # Add again without increment_if_exists
      assert_difference "OrderLine.count", 1 do
        result = Add.call(order: @order, sellable: @product, actor: @admin, increment_if_exists: false)
        assert result.success?
        assert_equal :created, result.action
      end

      assert_equal 2, @order.order_lines.count
    end

    test "sets line position correctly" do
      Add.call(order: @order, sellable: @product, actor: @admin)
      line = @order.order_lines.last
      assert_equal 1, line.position

      other_product = products(:nhl_puck)
      Add.call(order: @order, sellable: other_product, actor: @admin)
      other_line = @order.order_lines.last
      assert_equal 2, other_line.position
    end

    test "uses specified quantity" do
      result = Add.call(order: @order, sellable: @product, actor: @admin, quantity: 5)
      assert result.success?
      line = @order.order_lines.last
      assert_equal 5, line.quantity
    end

    test "applies customer tax code when customer is set" do
      exempt_customer = customers(:jane_doe)
      exempt_customer.update!(tax_code: tax_codes(:two)) # Tax-exempt code
      @order.update!(customer: exempt_customer)

      Add.call(order: @order, sellable: @product, actor: @admin)
      line = @order.order_lines.last

      assert_equal 0, line.tax_rate
      assert_equal tax_codes(:two), line.tax_code
    end

    test "applies product tax code when no customer is set" do
      Add.call(order: @order, sellable: @product, actor: @admin)
      line = @order.order_lines.last

      assert_equal tax_codes(:one).rate, line.tax_rate
      assert_equal tax_codes(:one), line.tax_code
    end

    test "applies auto-applied discounts after adding line" do
      # dragon_shield_red is in discount_items fixtures
      # 1 order-level discount (percentage_all) + 2 line-level discounts
      assert_difference "OrderDiscount.count", 1 do
        assert_difference "OrderLineDiscount.count", 2 do
          Add.call(order: @order, sellable: @product, actor: @admin)
        end
      end

      assert @order.order_discounts.exists?(discount_id: discounts(:percentage_all).id)
    end

    test "recalculates order totals after adding line" do
      Add.call(order: @order, sellable: @product, actor: @admin)
      @order.reload

      assert @order.subtotal > 0
      assert @order.total > 0
    end

    test "creates line_added event for new line" do
      assert_difference "OrderEvent.count", 1 do
        Add.call(order: @order, sellable: @product, actor: @admin)
      end

      event = OrderEvent.last
      assert_equal "line_added", event.event_type
      assert_equal @admin, event.actor
      assert_equal @order, event.order
      assert_equal @product.sellable_name, event.data["name"]
    end

    test "creates line_quantity_changed event when incrementing" do
      Add.call(order: @order, sellable: @product, actor: @admin)

      assert_difference "OrderEvent.count", 1 do
        Add.call(order: @order, sellable: @product, actor: @admin, increment_if_exists: true)
      end

      event = OrderEvent.last
      assert_equal "line_quantity_changed", event.event_type
      assert_equal @product.sellable_name, event.data["name"]
      assert_equal 2, event.data["new_quantity"]
    end

    test "works with services as sellable" do
      assert_difference "OrderLine.count", 1 do
        result = Add.call(order: @order, sellable: @service, actor: @admin)
        assert result.success?
        assert_equal :created, result.action
      end

      line = @order.order_lines.last
      assert_equal "Service", line.sellable_type
    end

    test "returns error when sellable is nil" do
      result = Add.call(order: @order, sellable: nil, actor: @admin)
      assert_not result.success?
      assert_includes result.error, "Sellable is required"
    end

    test "returns error when order is finalized" do
      completed_order = orders(:completed_order)
      result = Add.call(order: completed_order, sellable: @product, actor: @admin)
      assert_not result.success?
      assert_includes result.error, "Order cannot be modified"
    end

    test "applies discounts when incrementing quantity" do
      Add.call(order: @order, sellable: @product, actor: @admin)

      # Second call with increment should still apply discounts
      assert_difference "OrderEvent.count", 1 do
        Add.call(order: @order, sellable: @product, actor: @admin, increment_if_exists: true)
      end

      @order.reload
      assert @order.order_discounts.any?
    end

    test "correctly handles service sellables" do
      result = Add.call(order: @order, sellable: @service, actor: @admin)
      assert result.success?
      assert_equal @service.sellable_name, result.line.name
      assert_equal @service.sellable_code, result.line.code
    end
  end
end
