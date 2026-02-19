# frozen_string_literal: true

module AdminArea
  class DiscountsController < BaseController
    include Filterable

    before_action :set_discount, only: %i[
      show edit update destroy toggle_active search_items bulk_add_items
    ]

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
      @pagy_allowed, @allowed_items = pagy(
        @discount.allowed_items.includes(:discountable).order(created_at: :desc),
        items: 20,
        page_param: :allowed_page
      )
      @pagy_denied, @denied_items = pagy(
        @discount.denied_items.includes(:discountable).order(created_at: :desc),
        items: 20,
        page_param: :denied_page
      ) if @discount.per_item_discount?
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
      type  = params[:item_type].presence || "all"
      exclusion_type = params[:exclusion_type].presence || "allowed"

      @item_type = type
      @exclusion_type = exclusion_type
      @results = search_discountables(query, type)
      @discount_item_ids = @discount.discount_items
                                    .where(exclusion_type: exclusion_type)
                                    .where(discountable_type: type == "all" ? %w[Product Service ProductGroup] : type)
                                    .pluck(:discountable_id)

      respond_to do |format|
        format.html do
          frame_id = "discount_item_search_results_#{exclusion_type}"
          render turbo_frame: frame_id
        end
      end
    end

    def bulk_add_items
      exclusion_type = params[:exclusion_type].presence || "allowed"
      ids = params[:discountable_ids] || []
      types = params[:discountable_types] || []

      added_count = 0
      ids.each_with_index do |id, index|
        type = types[index] || "Product"
        next if @discount.discount_items.exists?(
          discountable_type: type,
          discountable_id: id,
          exclusion_type: exclusion_type
        )

        @discount.discount_items.create!(
          discountable_type: type,
          discountable_id: id,
          exclusion_type: exclusion_type
        )
        added_count += 1
      end

      redirect_to admin_discount_path(@discount),
                  notice: "#{added_count} items added to #{exclusion_type} list."
    rescue ActiveRecord::RecordInvalid => e
      redirect_to admin_discount_path(@discount),
                  alert: "Error adding items: #{e.message}"
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

      def search_discountables(query, type)
        results = []

        if query.present?
          # Search mode: return matching results
          if type == "all" || type == "Product"
            results += Product.kept.search(query).limit(10)
          end

          if type == "all" || type == "Service"
            results += Service.kept.search(query).limit(10)
          end

          if type == "all" || type == "ProductGroup"
            results += ProductGroup.search(query).limit(10)
          end
        else
          # Default mode: show recent items so user knows what's available
          if type == "all" || type == "Product"
            results += Product.kept.order(created_at: :desc).limit(10)
          end

          if type == "all" || type == "Service"
            results += Service.kept.order(created_at: :desc).limit(10)
          end

          if type == "all" || type == "ProductGroup"
            results += ProductGroup.order(created_at: :desc).limit(10)
          end
        end

        results
      end
  end
end
