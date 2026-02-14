# frozen_string_literal: true

module AdminArea
  class SuppliersController < BaseController
    include FilterableByDate

    before_action :set_supplier, only: %i[ show edit update destroy ]

    def index
      scope = Supplier.kept.order(:name)
      scope = scope.search(params[:q]) if params[:q].present?
      scope = apply_date_filters(scope)
      @pagy, @suppliers = pagy(:offset, scope)
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
