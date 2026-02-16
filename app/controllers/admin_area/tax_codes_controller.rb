# frozen_string_literal: true

module AdminArea
  class TaxCodesController < BaseController
    include Filterable

    before_action :set_tax_code, only: %i[ show edit update destroy ]

    def index
      @filter_config = FilterConfig.new(:tax_codes, admin_tax_codes_path,
                                        sort_default: "code", sort_default_direction: "asc",
                                        search_placeholder: "Search tax codes...") do |f|
        f.number_range :rate,       label: "Rate"
        f.date_range   :created_at, label: "Created"

        f.column :code,            label: "Code",      default: true,  sortable: true
        f.column :name,            label: "Name",      default: true,  sortable: true
        f.column :rate,            label: "Rate",      default: true,  sortable: true
        f.column :exemption_type,  label: "Exemption", default: false
        f.column :province_code,   label: "Province",  default: false
        f.column :created_at,      label: "Created",   default: true,  sortable: true
        f.column :updated_at,      label: "Updated",   default: false, sortable: true
      end
      @saved_queries = current_user.saved_queries.for_resource("tax_codes")

      @pagy, @tax_codes = filter_and_paginate(
        TaxCode.kept,
        config: @filter_config
      )
    end

    def new
      @tax_code = TaxCode.new
    end

    def create
      @tax_code = TaxCode.new(tax_code_params)
      if @tax_code.save
        redirect_to admin_tax_codes_path, notice: "Tax code created."
      else
        render :new, status: :unprocessable_entity
      end
    end

    def show
    end

    def edit
    end

    def update
      if @tax_code.update(tax_code_params)
        redirect_to admin_tax_codes_path, notice: "Tax code updated."
      else
        render :edit, status: :unprocessable_entity
      end
    end

    def destroy
      @tax_code.discard
      redirect_to admin_tax_codes_path, notice: "Tax code removed."
    end

    private

      def set_tax_code
        @tax_code = TaxCode.find(params[:id])
      end

      def tax_code_params
        p = params.require(:tax_code).permit(:code, :name, :rate, :exemption_type, :province_code, :notes)
        # Convert percentage input (e.g. 13) to decimal (0.13)
        p[:rate] = (p[:rate].to_f / 100).round(4) if p[:rate].present?
        p
      end
  end
end
