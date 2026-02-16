# frozen_string_literal: true

class ProductsController < ApplicationController
  include Filterable

  load_and_authorize_resource

  def index
    @suppliers = Supplier.kept.order(:name)
    @pagy, @products = filter_and_paginate(
      @products.kept.includes(:tax_code, :supplier, :product_group),
      sort_allowed: %w[name code selling_price stock_level created_at updated_at],
      sort_default: "name", sort_default_direction: "asc",
      filters: ->(scope) {
        scope = scope.where(supplier_id: params[:supplier_id]) if params[:supplier_id].present?
        scope
      }
    )
  end

  def new
  end

  def create
    @product.added_by = current_user
    @product.images.attach(product_params[:images]) if product_params[:images].present?

    if @product.save
      redirect_to products_path, notice: "Product created."
    else
      render :new, status: :unprocessable_entity
    end
  end

  def show
  end

  def edit
  end

  def update
    @product.images.attach(product_params[:images]) if product_params[:images].present?

    if @product.update(product_params.except(:images))
      redirect_to product_path(@product), notice: "Product updated."
    else
      render :edit, status: :unprocessable_entity
    end
  end

  def destroy
    @product.discard
    redirect_to products_path, notice: "Product removed."
  end

  def purge_image
    image = @product.images.find(params[:image_id])
    image.purge
    redirect_to edit_product_path(@product), notice: "Image removed."
  end

  private

    def product_params
      params.require(:product).permit(
        :code, :name, :selling_price, :purchase_price,
        :stock_level, :reorder_level, :order_quantity,
        :unit_cost, :items_per_unit,
        :supplier_reference, :notes, :product_url,
        :tax_code_id, :supplier_id, :product_group_id,
        :sync_to_shopify,
        images: []
      )
    end
end
