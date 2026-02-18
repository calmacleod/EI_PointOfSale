# frozen_string_literal: true

class SearchController < ApplicationController
  def index
    raw_query = params[:q].to_s.strip
    query = sanitize_search_query(raw_query)
    limit = [ (params[:limit] || 10).to_i, 25 ].min
    type_filter = params[:type].to_s.presence

    # Fast path: exact code match for barcode scans
    exact = exact_code_matches(raw_query, type_filter:)

    # Fill remaining slots with fuzzy pg_search results
    remaining = limit - exact.size
    if remaining > 0 && query.present?
      exact_keys = exact.map { |r| [ r[:type], r[:record_id] ] }.to_set
      docs = PgSearch.multisearch(query)
      docs = docs.where(searchable_type: type_filter) if type_filter.present?
      docs = docs.limit(limit)
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

  def product_results
    raw_query = params[:q].to_s.strip
    limit = [ (params[:limit] || 20).to_i, 50 ].min
    type_filter = params[:type].to_s.presence

    @results = []
    @selected_index = params[:selected].to_i

    if raw_query.present?
      # Fast path: exact code match
      if type_filter.nil? || type_filter == "Product"
        product = Product.kept.find_by(code: raw_query)
        @results << { type: "Product", record: product } if product
      end

      if type_filter.nil? || type_filter == "Service"
        service = Service.kept.find_by(code: raw_query)
        @results << { type: "Service", record: service } if service
      end

      # Fill with fuzzy search if needed
      if @results.empty? && raw_query.length >= 2
        query = sanitize_search_query(raw_query)
        docs = PgSearch.multisearch(query)
        docs = docs.where(searchable_type: [ "Product", "Service" ])
        docs = docs.where(searchable_type: type_filter) if type_filter.present?

        docs.limit(limit).each do |doc|
          record = doc.searchable
          next unless record && record.respond_to?(:kept?)

          @results << { type: doc.searchable_type, record: record }
        end
      end
    end

    respond_to do |format|
      format.html { render partial: "search/product_search_results", locals: { results: @results, selected_index: @selected_index } }
    end
  end

  private

    # Exact code lookup against indexed code columns.
    # Uses the raw (unsanitized) query so "WH-BLK-001" matches the stored code exactly.
    def exact_code_matches(query, type_filter: nil)
      return [] if query.blank?

      results = []

      if type_filter.nil? || type_filter == "Product"
        if (product = Product.kept.find_by(code: query))
          results << build_result(product, "Product")
        end
      end

      if type_filter.nil? || type_filter == "Service"
        if (service = Service.kept.find_by(code: query))
          results << build_result(service, "Service")
        end
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
      when "Product" then record.name.presence || record.code
      when "Service" then record.name
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
      when "TaxCode" then nil
      else nil
      end
    end

    def search_url_for(record, type)
      case type
      when "Product" then product_path(record)
      when "Service" then service_path(record)
      when "User" then admin_user_path(record)
      when "TaxCode" then admin_tax_code_path(record)
      when "Category", "Supplier" then products_path
      when "Customer" then customer_path(record)
      else root_path
      end
    end
end
