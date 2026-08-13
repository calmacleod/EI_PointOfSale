# frozen_string_literal: true

module AdminArea
  class DiscountsController < BaseController
    include Filterable

    before_action :set_discount, only: %i[show edit update destroy toggle_active]

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
      @pagy, @discounts = filter_and_paginate(
        Discount.kept.select(:id, :name, :discount_type, :value, :active, :starts_at, :ends_at),
        config: @filter_config
      )
    end

    def show; end

    def new
      @discount = Discount.new(active: true)
    end

    def create
      @discount = Discount.new(discount_params)
      if @discount.save
        redirect_to admin_discount_path(@discount), notice: "Discount created."
      else
        render_inertia_page(action: :new, status: :unprocessable_entity)
      end
    end

    def edit
    end

    def update
      if @discount.update(discount_params)
        redirect_to admin_discount_path(@discount), notice: "Discount updated."
      else
        render_inertia_page(action: :edit, status: :unprocessable_entity)
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
