# frozen_string_literal: true

# Generic concern for controllers that list records with search, filters,
# column sorting, and pagination.
#
# Includes Sortable automatically.
#
# Usage:
#
#   class ProductsController < ApplicationController
#     include Filterable
#
#     def index
#       @filter_config = FilterConfig.new(:products, products_path) do |f|
#         f.association :supplier_id, label: "Supplier", collection: -> { Supplier.kept.order(:name) }
#         f.date_range  :created_at,  label: "Created"
#         f.column :name, label: "Product", default: true, sortable: true
#       end
#       @saved_queries = current_user.saved_queries.for_resource("products")
#
#       @pagy, @products = filter_and_paginate(
#         Product.kept.includes(:supplier),
#         config: @filter_config
#       )
#     end
#   end
#
module Filterable
  extend ActiveSupport::Concern

  included do
    include Sortable
  end

  private

    # Applies search, declared filters, sorting, and pagination using a FilterConfig.
    #
    # Options:
    #   config: - A FilterConfig instance (required).
    #   items:  - Override per-page count.
    #
    # Returns [pagy, records].
    #
    def filter_and_paginate(scope, config:, items: nil)
      scope = apply_search(scope, config.search_scope)
      scope = config.apply_filters(scope, params)

      scope = apply_sort(scope,
                         allowed: config.sortable_columns,
                         default: config.sort_default,
                         default_direction: config.sort_default_direction)

      pagy_opts = items ? { limit: items } : {}
      pagy(:offset, scope, **pagy_opts)
    end

    def apply_search(scope, search_scope_name)
      return scope if search_scope_name == false
      return scope if params[:q].blank?

      query = sanitize_search_query(params[:q])
      return scope if query.blank?

      scope.public_send(search_scope_name, query)
    end
end
