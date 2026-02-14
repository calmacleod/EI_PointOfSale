# frozen_string_literal: true

class SearchController < ApplicationController
  def index
    query = params[:q].to_s.strip
    limit = [ (params[:limit] || 10).to_i, 25 ].min
    docs = query.present? ? PgSearch.multisearch(query).limit(limit) : []
    @results = docs.filter_map { |doc| search_result_for(doc) }

    respond_to do |format|
      format.turbo_stream
      format.html { redirect_back fallback_location: root_path }
      format.json { render json: { results: @results } }
    end
  end

  private

    def search_result_for(doc)
      record = doc.searchable
      return nil unless record

      {
        id: doc.id,
        type: doc.searchable_type,
        label: search_label_for(record, doc.searchable_type),
        sublabel: search_sublabel_for(record, doc.searchable_type),
        url: search_url_for(record, doc.searchable_type),
        icon: doc.searchable_type.underscore
      }
    rescue StandardError
      nil
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
      when "User" then user_path(record)
      when "ProductVariant" then product_product_variant_path(record.product, record)
      when "TaxCode" then admin_tax_code_path(record)
      when "Category", "Supplier" then products_path
      else root_path
      end
    end
end
