# frozen_string_literal: true

class ProductsController < ApplicationController
  load_and_authorize_resource

  def index
    scope = @products.kept
      .includes(:tax_code, :supplier, :variants)
      .order(:name)
    scope = scope.search(params[:q]) if params[:q].present?
    scope = scope.where(supplier_id: params[:supplier_id]) if params[:supplier_id].present?
    scope = apply_date_filters(scope)
    @suppliers = Supplier.kept.order(:name)
    @pagy, @products = pagy(:offset, scope)
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

  def show
    @product.variants.load
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
