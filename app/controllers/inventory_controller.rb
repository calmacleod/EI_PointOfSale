# frozen_string_literal: true

class InventoryController < ApplicationController
  authorize_resource class: false

  def show
  end

  def lookup
    product = if params[:product_id].present?
      Product.kept.find_by(id: params[:product_id])
    else
      Product.find_by_exact_code(params[:code].to_s.strip)
    end

    if product
      render json: {
        found: true,
        id: product.id,
        code: product.code,
        name: product.name,
        supplier: product.supplier&.name,
        stock_level: product.stock_level,
        reorder_level: product.reorder_level
      }
    else
      render json: { found: false }
    end
  end

  def restock
    items = (params[:restocks] || []).filter_map do |r|
      next if r[:quantity].to_i <= 0
      { product_id: r[:product_id], quantity: r[:quantity], notes: r[:notes] }
    end

    if items.empty?
      redirect_to inventory_path, alert: "No restock quantities entered."
      return
    end

    result = Products::BulkRestockService.call(items: items, user: Current.user)

    if result.success?
      redirect_to inventory_path, notice: "Successfully restocked #{result.successes.size} product(s)."
    else
      redirect_to inventory_path, alert: "Restock failed: #{result.failures.map { |f| f[:errors].join(", ") }.join("; ")}"
    end
  end

  def import
    file = params[:csv_file]

    unless file.present?
      redirect_to inventory_path, alert: "Please select a CSV file."
      return
    end

    rows = parse_csv(file)

    if rows.empty?
      redirect_to inventory_path, alert: "No valid rows found in CSV."
      return
    end

    result = Products::BulkRestockService.call(items: rows, user: Current.user)

    if result.success?
      redirect_to inventory_path, notice: "CSV imported: #{result.successes.size} product(s) restocked."
    else
      redirect_to inventory_path, alert: "CSV import had errors: #{result.failures.map { |f| f[:errors].join(", ") }.join("; ")}"
    end
  end

  private

    def parse_csv(file)
      require "csv"
      rows = []
      CSV.foreach(file.path, headers: true, header_converters: :symbol) do |row|
        code = (row[:code] || row[:product_code] || row[:stock_code]).to_s.strip
        quantity = (row[:quantity] || row[:qty]).to_i
        notes = (row[:notes] || "").to_s.strip.presence

        next if code.blank? || quantity <= 0

        product = Product.find_by_exact_code(code)
        next unless product

        rows << { product_id: product.id, quantity: quantity, notes: notes }
      end
      rows
    end
end
