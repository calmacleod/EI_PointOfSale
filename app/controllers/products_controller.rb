# frozen_string_literal: true

class ProductsController < ApplicationController
  load_and_authorize_resource

  def index
    @pagy, @products = pagy(:offset,
      @products.kept
        .includes(:tax_code, :supplier, :variants)
        .order(:name)
    )
  end

  def new
  end

  def create
    @product.added_by = current_user
    if @product.save
      redirect_to products_path, notice: "Product created."
    else
      render :new, status: :unprocessable_entity
    end
  end

  def edit
    @product.variants.load
  end

  def update
    if @product.update(product_params)
      redirect_to products_path, notice: "Product updated."
    else
      render :edit, status: :unprocessable_entity
    end
  end

  def destroy
    @product.discard
    redirect_to products_path, notice: "Product removed."
  end

  private

    def product_params
      params.require(:product).permit(:name, :tax_code_id, :supplier_id, :product_url)
    end
end
