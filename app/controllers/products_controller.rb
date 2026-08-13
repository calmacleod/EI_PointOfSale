# frozen_string_literal: true

class ProductsController < ApplicationController
  include Filterable

  load_and_authorize_resource

  def index
    @filter_config = FilterConfig.new(:products, products_path,
                                      sort_default: "name", sort_default_direction: "asc",
                                      search_placeholder: "Search products...") do |f|
      f.multi_select :supplier_id,       label: "Supplier",      collection: -> { Supplier.kept.order(:name).load }
      f.association  :tax_code_id,      label: "Tax Code",      collection: -> { TaxCode.kept.order(:code).load }, display: :code
      f.association  :product_group_id, label: "Product Group",  collection: -> { ProductGroup.order(:name).load }
      f.multi_select :category_ids,     label: "Categories",
                     collection: -> { Category.kept.order(:name) },
                     scope: ->(rel, ids) { rel.joins(:categories).where(categories: { id: ids }).distinct }
      f.boolean      :sync_to_shopify,  label: "Shopify Sync"
      f.number_range :selling_price,    label: "Price"
      f.number_range :stock_level,      label: "Stock"
      f.date_range   :created_at,       label: "Created"
      f.date_range   :updated_at,       label: "Updated"

      f.column :code,            label: "Code",     default: true,  sortable: true,  width: "7rem"
      f.column :name,            label: "Product",  default: true,  sortable: true,  width: "18rem"
      f.column :selling_price,   label: "Price",    default: true,  sortable: true,  width: "5rem"
      f.column :stock_level,     label: "Stock",    default: true,  sortable: true,  width: "4.5rem"
      f.column :supplier,        label: "Supplier", default: true,                   width: "12rem"
      f.column :tax_code,        label: "Tax",      default: false,                  width: "4.5rem"
      f.column :purchase_price,  label: "Cost",     default: false, sortable: true,  width: "5rem"
      f.column :reorder_level,   label: "Reorder",  default: false, sortable: true,  width: "5.5rem"
      f.column :product_group,   label: "Group",    default: false,                  width: "10rem"
      f.column :sync_to_shopify, label: "Shopify",  default: false,                  width: "5rem"
      f.column :created_at,      label: "Created",  default: true,  sortable: true,  width: "8.5rem"
      f.column :updated_at,      label: "Updated",  default: false, sortable: true,  width: "8.5rem"
    end
    @pagy, @products = filter_and_paginate(
      @products.kept
               .select(:id, :code, :name, :selling_price, :purchase_price,
                       :stock_level, :reorder_level, :sync_to_shopify,
                       :supplier_id, :tax_code_id, :product_group_id,
                       :discarded_at,
                       Arel.sql("to_char(created_at AT TIME ZONE 'UTC', 'YYYY-MM-DD\"T\"HH24:MI:SS\"Z\"') AS created_at_s"),
                       Arel.sql("to_char(updated_at AT TIME ZONE 'UTC', 'YYYY-MM-DD\"T\"HH24:MI:SS\"Z\"') AS updated_at_s"))
               .includes(:tax_code, :supplier, :product_group),
      config: @filter_config,
      count: cached_product_count,
      ttl: 10.minutes
    )
  end

  def new
  end

  def create
    @product.added_by = current_user
    images = Array(product_params[:images]).reject(&:blank?)
    @product.images.attach(images) if images.any?

    if @product.save
      redirect_to products_path, notice: "Product created."
    else
      render_inertia_page(action: :new, status: :unprocessable_entity)
    end
  end

  def show
    respond_to do |format|
      format.html { fresh_when @product }
      format.json {
        render json: {
          id: @product.id,
          name: @product.name,
          code: @product.code,
          selling_price: @product.selling_price,
          cost_price: @product.purchase_price,
          stock_level: @product.stock_level,
          reorder_level: @product.reorder_level,
          supplier: @product.supplier&.name,
          category: @product.categories.first&.name,
          tax_code: @product.tax_code ? "#{@product.tax_code.name} (#{(@product.tax_code.rate * 100).round(1)}%)" : nil,
          description: @product.notes,
          product_group: @product.product_group&.name
        }
      }
    end
  end

  def edit
  end

  def update
    images = Array(product_params[:images]).reject(&:blank?)
    @product.images.attach(images) if images.any?

    if @product.update(product_params.except(:images))
      redirect_to product_path(@product), notice: "Product updated."
    else
      render_inertia_page(action: :edit, status: :unprocessable_entity)
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

    def cached_product_count
      filter_active = @filter_config.all_filter_param_keys.any? do |key|
        Array(params[key]).any?(&:present?)
      end

      Product.kept_count unless filter_active
    end

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
