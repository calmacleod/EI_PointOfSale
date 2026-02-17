# frozen_string_literal: true

module AdminArea
  class DiscountItemsController < BaseController
    before_action :set_discount, only: :create
    before_action :set_discount_item, only: :destroy

    def create
      discountable = find_discountable(params[:discountable_type], params[:discountable_id])
      @discount_item = @discount.discount_items.build(discountable: discountable)

      if @discount_item.save
        @discount_items = @discount.discount_items.includes(:discountable).reload
        respond_to do |format|
          format.turbo_stream {
            render turbo_stream: turbo_stream.replace(
              "discount_items",
              partial: "admin_area/discounts/items",
              locals: { discount: @discount, discount_items: @discount_items }
            )
          }
          format.html { redirect_to admin_discount_path(@discount) }
        end
      else
        redirect_to admin_discount_path(@discount), alert: "Could not add item."
      end
    end

    def destroy
      discount = @discount_item.discount
      @discount_item.destroy!
      @discount_items = discount.discount_items.includes(:discountable).reload

      respond_to do |format|
        format.turbo_stream {
          render turbo_stream: turbo_stream.replace(
            "discount_items",
            partial: "admin_area/discounts/items",
            locals: { discount: discount, discount_items: @discount_items }
          )
        }
        format.html { redirect_to admin_discount_path(discount) }
      end
    end

    private

      def set_discount
        @discount = Discount.find(params[:discount_id])
      end

      def set_discount_item
        @discount_item = DiscountItem.find(params[:id])
      end

      def find_discountable(type, id)
        case type
        when "Product" then Product.kept.find(id)
        when "Service" then Service.kept.find(id)
        else raise ArgumentError, "Unknown discountable type: #{type}"
        end
      end
  end
end
