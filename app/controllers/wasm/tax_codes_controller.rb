# frozen_string_literal: true

module Wasm
  class TaxCodesController < ActionController::API
    # GET /wasm/tax_codes
    def index
      render json: TaxCode.order(:code).as_json(only: %i[id code name rate])
    end

    # POST /wasm/tax_codes
    # Body: { tax_codes: [{ id, code, name, rate }] }
    # Upserts all provided tax codes into PGlite.
    def create
      tax_codes_data = params[:tax_codes] || []

      upserted = tax_codes_data.map do |attrs|
        TaxCode.find_or_initialize_by(id: attrs[:id]).tap do |tc|
          tc.code = attrs[:code]
          tc.name = attrs[:name]
          tc.rate = attrs[:rate].to_f
          tc.save!
        end
      end

      render json: { upserted: upserted.length }, status: :ok
    end
  end
end
