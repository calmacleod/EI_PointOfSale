# frozen_string_literal: true

# Generic concern for controllers that list records with search, custom filters,
# date filters, column sorting, and pagination.
#
# Includes FilterableByDate and Sortable automatically.
#
# Usage:
#
#   class CustomersController < ApplicationController
#     include Filterable
#
#     def index
#       @pagy, @customers = filter_and_paginate(
#         Customer.kept.includes(:added_by),
#         search: :search,
#         sort_allowed: %w[name email created_at],
#         sort_default: "name",
#         sort_default_direction: "asc",
#         filters: -> (scope) {
#           scope = scope.where(active: true) if params[:filter] == "active"
#           scope
#         }
#       )
#     end
#   end
#
module Filterable
  extend ActiveSupport::Concern

  included do
    include FilterableByDate
    include Sortable
  end

  private

    # Applies search, custom filters, date filters, sorting, and pagination.
    #
    # Options:
    #   search:                 - pg_search scope name (default: :search), or false.
    #   filters:                - Callable for custom filters (receives scope).
    #   sort_allowed:           - Array of sortable column names (default: %w[created_at]).
    #   sort_default:           - Default sort column (default: "created_at").
    #   sort_default_direction: - Default sort direction (default: "desc").
    #   items:                  - Override per-page count.
    #
    # Returns [pagy, records].
    #
    def filter_and_paginate(scope, search: :search, filters: nil,
                            sort_allowed: nil, sort_default: "created_at",
                            sort_default_direction: "desc", items: nil)
      scope = apply_search(scope, search)
      scope = filters.call(scope) if filters.respond_to?(:call)
      scope = apply_date_filters(scope)

      allowed = sort_allowed || detect_sortable_columns(scope)
      scope = apply_sort(scope, allowed: allowed, default: sort_default,
                                default_direction: sort_default_direction)

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

    # If no sort_allowed list is provided, fall back to a safe set of columns
    # from the model's table.
    def detect_sortable_columns(scope)
      return %w[created_at] unless scope.respond_to?(:model)

      scope.model.column_names
    rescue StandardError
      %w[created_at]
    end
end
