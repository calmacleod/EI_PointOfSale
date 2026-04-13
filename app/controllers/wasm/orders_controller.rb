# frozen_string_literal: true

# Handles order calculation requests from the WASM runtime running in the browser.
# This controller runs inside app.wasm via wasmify-rails, with PGlite as the database.
# It is intentionally lightweight — no auth, no sessions, no CSRF.
module Wasm
  class OrdersController < ActionController::API
    # POST /wasm/orders/calculate
    # Body: { lines: [{ name, unit_price, quantity, tax_code_id }] }
    # Returns: { subtotal, tax_total, discount_total, total, lines: [{ ... }] }
    def calculate
      lines_data = params[:lines] || []
      tax_codes = TaxCode.where(id: lines_data.filter_map { |l| l[:tax_code_id] }).index_by(&:id)

      result_lines = lines_data.map do |line|
        unit_price = line[:unit_price].to_f
        quantity   = line[:quantity].to_i
        tax_code   = tax_codes[line[:tax_code_id].to_i]
        tax_rate   = tax_code&.rate&.to_f || 0.0

        subtotal   = (unit_price * quantity).round(2)
        tax_amount = (subtotal * tax_rate).round(2)
        line_total = (subtotal + tax_amount).round(2)

        { name: line[:name], unit_price:, quantity:, tax_rate:, subtotal:, tax_amount:, line_total: }
      end

      subtotal       = result_lines.sum { |l| l[:subtotal] }.round(2)
      tax_total      = result_lines.sum { |l| l[:tax_amount] }.round(2)
      discount_total = 0
      total          = (subtotal + tax_total).round(2)

      render json: { subtotal:, tax_total:, discount_total:, total:, lines: result_lines }
    end
  end
end
