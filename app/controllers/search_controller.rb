# frozen_string_literal: true

class SearchController < ApplicationController
  def index
    raw_query = params[:q].to_s.strip
    query = sanitize_search_query(raw_query)
    limit = [ (params[:limit] || 10).to_i, 25 ].min

    # Fast path: exact code match for barcode scans
    exact = exact_code_matches(raw_query)

    # Fill remaining slots with fuzzy pg_search results
    remaining = limit - exact.size
    if remaining > 0 && query.present?
      exact_keys = exact.map { |r| [ r[:type], r[:record_id] ] }.to_set
      docs = PgSearch.multisearch(query).limit(limit)
      fuzzy = docs.filter_map { |doc| search_result_for(doc) }
      fuzzy.reject! { |r| exact_keys.include?([ r[:type], r[:record_id] ]) }
      @results = exact + fuzzy.first(remaining)
    else
      @results = exact
    end

    respond_to do |format|
      format.turbo_stream
      format.html { redirect_back fallback_location: root_path }
      format.json { render json: { results: @results } }
    end
  end

  private

    # Exact code lookup against indexed code columns.
    # Uses the raw (unsanitized) query so "WH-BLK-001" matches the stored code exactly.
    def exact_code_matches(query)
      return [] if query.blank?

      results = []

      if (variant = ProductVariant.kept.find_by(code: query))
        results << build_result(variant, "ProductVariant")
      end

      if (service = Service.kept.find_by(code: query))
        results << build_result(service, "Service")
      end

      results
    end

    def search_result_for(doc)
      record = doc.searchable
      return nil unless record
      return nil if record.is_a?(User) && !(current_user&.is_a?(Admin))

      build_result(record, doc.searchable_type)
    rescue StandardError
      nil
    end

    def build_result(record, type)
      {
        id: record.id,
        record_id: record.id,
        type: type,
        label: search_label_for(record, type),
        sublabel: search_sublabel_for(record, type),
        url: search_url_for(record, type),
        icon: type.underscore
      }
    end

    def search_label_for(record, type)
      case type
      when "User" then record.email_address.presence || record.name.presence || "User ##{record.id}"
      when "Product" then record.name
      when "Service" then record.name
      when "ProductVariant" then record.code.presence || record.name.presence || "Variant ##{record.id}"
      when "Category" then record.name
      when "Supplier" then record.name
      when "TaxCode" then "#{record.code} - #{record.name}"
      when "Customer" then record.name
      else record.try(:name) || record.to_s
      end
    end

    def search_sublabel_for(record, type)
      case type
      when "User" then record.name.presence
      when "Product" then record.supplier&.name
      when "ProductVariant" then record.product&.name
      when "TaxCode" then nil
      else nil
      end
    end

    def search_url_for(record, type)
      case type
      when "Product" then product_path(record)
      when "Service" then service_path(record)
      when "User" then admin_user_path(record)
      when "ProductVariant" then product_product_variant_path(record.product, record)
      when "TaxCode" then admin_tax_code_path(record)
      when "Category", "Supplier" then products_path
      when "Customer" then customer_path(record)
      else root_path
      end
    end
end
