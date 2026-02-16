# frozen_string_literal: true

class ProductsController < ApplicationController
  include Filterable

  load_and_authorize_resource

  def index
    @filter_config = FilterConfig.new(:products, products_path,
                                      sort_default: "name", sort_default_direction: "asc",
                                      search_placeholder: "Search products...") do |f|
      f.association  :supplier_id,      label: "Supplier",      collection: -> { Supplier.kept.order(:name) }
      f.association  :tax_code_id,      label: "Tax Code",      collection: -> { TaxCode.kept.order(:code) }, display: :code
      f.association  :product_group_id, label: "Product Group",  collection: -> { ProductGroup.order(:name) }
      f.boolean      :sync_to_shopify,  label: "Shopify Sync"
      f.number_range :selling_price,    label: "Price"
      f.number_range :stock_level,      label: "Stock"
      f.date_range   :created_at,       label: "Created"
      f.date_range   :updated_at,       label: "Updated"

      f.column :code,           label: "Code",     default: true,  sortable: true
      f.column :name,           label: "Product",  default: true,  sortable: true
      f.column :selling_price,  label: "Price",    default: true,  sortable: true
      f.column :stock_level,    label: "Stock",    default: true,  sortable: true
      f.column :supplier,       label: "Supplier", default: true
      f.column :tax_code,       label: "Tax",      default: false
      f.column :purchase_price, label: "Cost",     default: false, sortable: true
      f.column :reorder_level,  label: "Reorder",  default: false, sortable: true
      f.column :product_group,  label: "Group",    default: false
      f.column :sync_to_shopify, label: "Shopify", default: false
      f.column :created_at,     label: "Created",  default: true,  sortable: true
      f.column :updated_at,     label: "Updated",  default: false, sortable: true
    end
    @saved_queries = current_user.saved_queries.for_resource("products")

    @pagy, @products = filter_and_paginate(
      @products.kept.includes(:tax_code, :supplier, :product_group),
      config: @filter_config
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
