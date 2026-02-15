# frozen_string_literal: true

module AdminArea
  class SuppliersController < BaseController
    include Filterable

    before_action :set_supplier, only: %i[ show edit update destroy ]

    def index
      @pagy, @suppliers = filter_and_paginate(
        Supplier.kept,
        sort_allowed: %w[name phone created_at],
        sort_default: "name", sort_default_direction: "asc"
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
