# frozen_string_literal: true

module AdminArea
  class SuppliersController < BaseController
    include Filterable

    before_action :set_supplier, only: %i[ show edit update destroy ]

    def index
      @filter_config = FilterConfig.new(:suppliers, admin_suppliers_path,
                                        sort_default: "name", sort_default_direction: "asc",
                                        search_placeholder: "Search suppliers...") do |f|
        f.date_range :created_at, label: "Created"
        f.date_range :updated_at, label: "Updated"

        f.column :name,       label: "Name",    default: true, sortable: true
        f.column :phone,      label: "Phone",   default: true, sortable: true
        f.column :created_at, label: "Created", default: true, sortable: true
        f.column :updated_at, label: "Updated", default: false, sortable: true
      end
      @saved_queries = current_user.saved_queries.for_resource("suppliers")

      @pagy, @suppliers = filter_and_paginate(
        Supplier.kept,
        config: @filter_config
      )
    end

    def new
      @supplier = Supplier.new
    end

    def create
      @supplier = Supplier.new(supplier_params)
      if @supplier.save
        redirect_to admin_suppliers_path, notice: "Supplier created."
      else
        render :new, status: :unprocessable_entity
      end
    end

    def show
    end

    def edit
    end

    def update
      if @supplier.update(supplier_params)
        redirect_to admin_suppliers_path, notice: "Supplier updated."
      else
        render :edit, status: :unprocessable_entity
      end
    end

    def destroy
      @supplier.discard
      redirect_to admin_suppliers_path, notice: "Supplier removed."
    end

    private

      def set_supplier
        @supplier = Supplier.find(params[:id])
      end

      def supplier_params
        params.require(:supplier).permit(:name, :phone)
      end
  end
end
