# frozen_string_literal: true

module AdminArea
  class TaxCodesController < BaseController
    before_action :set_tax_code, only: %i[ edit update destroy ]

    def index
      @tax_codes = TaxCode.kept.order(:code)
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
