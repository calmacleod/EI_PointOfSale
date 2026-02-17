# frozen_string_literal: true

module AdminArea
  class DiscountsController < BaseController
    include Filterable

    before_action :set_discount, only: %i[show edit update destroy toggle_active search_items]

    def index
      @filter_config = FilterConfig.new(:discounts, admin_discounts_path,
                                        sort_default: "name", sort_default_direction: "asc",
                                        search_placeholder: "Search discounts...") do |f|
        f.boolean :active, label: "Active"
        f.select  :discount_type, label: "Type",
                  options: Discount.discount_types.keys.map { |k| [ k.humanize, k ] }
        f.date_range :starts_at, label: "Starts"
        f.date_range :ends_at,   label: "Ends"

        f.column :name,          label: "Name",    default: true, sortable: true
        f.column :discount_type, label: "Type",    default: true, sortable: true
        f.column :value,         label: "Value",   default: true
        f.column :active,        label: "Active",  default: true, sortable: true
        f.column :starts_at,     label: "Starts",  default: true, sortable: true
        f.column :ends_at,       label: "Ends",    default: true, sortable: true
      end
      @saved_queries = current_user.saved_queries.for_resource("discounts")

      @pagy, @discounts = filter_and_paginate(
        Discount.kept,
        config: @filter_config
      )
    end

    def show
      @discount_items = @discount.discount_items.includes(:discountable)
    end

    def new
      @discount = Discount.new(active: true)
    end

    def create
      @discount = Discount.new(discount_params)
      if @discount.save
        redirect_to admin_discount_path(@discount), notice: "Discount created."
      else
        render :new, status: :unprocessable_entity
      end
    end

    def edit
    end

    def update
      if @discount.update(discount_params)
        redirect_to admin_discount_path(@discount), notice: "Discount updated."
      else
        render :edit, status: :unprocessable_entity
      end
    end

    def destroy
      @discount.discard
      redirect_to admin_discounts_path, notice: "Discount removed."
    end

    def toggle_active
      @discount.update!(active: !@discount.active)
      redirect_to admin_discount_path(@discount),
                  notice: "Discount #{@discount.active? ? 'activated' : 'deactivated'}."
    end

    def search_items
      query = params[:q].to_s.strip
      type  = params[:item_type].presence || "Product"

      @item_type = type
      @discount_item_ids = @discount.discount_items
                                    .where(discountable_type: type)
                                    .pluck(:discountable_id)

      @results = if query.present?
        klass = type == "Service" ? Service : Product
        klass.kept.search(query).limit(20)
      else
        []
      end

      render partial: "search_results", locals: {
        discount: @discount,
        results: @results,
        item_type: @item_type,
        discount_item_ids: @discount_item_ids
      }
    end

    private

      def set_discount
        @discount = Discount.find(params[:id])
      end

      def discount_params
        params.require(:discount).permit(
          :name, :description, :discount_type, :value,
          :active, :starts_at, :ends_at, :applies_to_all
        )
      end
  end
end
