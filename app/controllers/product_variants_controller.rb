# frozen_string_literal: true

class ProductVariantsController < ApplicationController
  load_and_authorize_resource :product
  load_and_authorize_resource :product_variant, through: :product, through_association: :variants

  def new
  end

  def create
    if @product_variant.save
      redirect_to edit_product_path(@product), notice: "Variant added."
    else
      render :new, status: :unprocessable_entity
    end
  end

  def show
  end

  def edit
  end

  def update
    if @product_variant.update(product_variant_params)
      redirect_to edit_product_path(@product), notice: "Variant updated."
    else
      render :edit, status: :unprocessable_entity
    end
  end

  def destroy
    @product_variant.discard
    redirect_to edit_product_path(@product), notice: "Variant removed."
  end

  private

    def product_variant_params
      params.require(:product_variant).permit(
        :code,
        :name,
        :selling_price,
        :purchase_price,
        :stock_level,
        :reorder_level,
        :unit_cost,
        :supplier_id,
        :supplier_reference,
        :notes
      )
    end
end
