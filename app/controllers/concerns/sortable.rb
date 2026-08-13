# frozen_string_literal: true

# Adds column sorting to index actions via `sort_column` and `sort_direction`
# params. Allowlisted columns prevent SQL injection.
#
# Usage in a controller:
#
#   include Sortable
#
#   def index
#     scope = apply_sort(Customer.kept, allowed: %w[name email created_at], default: "name")
#     # ...
#   end
#
# The page presenter serializes the active sort and sortable columns for the
# Svelte index screen, which sends `sort` and `dir` back as query parameters.
#
module Sortable
  extend ActiveSupport::Concern

  included do
    helper_method :current_sort_column, :current_sort_direction
  end

  private

    # Applies ORDER BY to the scope based on `params[:sort]` and `params[:dir]`.
    #
    # Options:
    #   allowed: - Array of column name strings that are valid sort targets.
    #   default: - Default column when no sort param is given (default: "created_at").
    #   default_direction: - Default direction (default: "desc").
    #
    # Returns the sorted scope. Does NOT remove existing order — call `reorder`
    # upstream if you need to replace an existing order clause.
    #
    def apply_sort(scope, allowed:, default: "created_at", default_direction: "desc")
      @sort_allowed_columns = allowed.map(&:to_s)
      @sort_default_column = default.to_s
      @sort_default_direction = default_direction.to_s

      column    = current_sort_column
      direction = current_sort_direction

      scope.reorder(column => direction.to_sym)
    end

    def current_sort_column
      col = params[:sort].to_s
      if @sort_allowed_columns&.include?(col)
        col
      else
        @sort_default_column || "created_at"
      end
    end

    def current_sort_direction
      dir = params[:dir].to_s.downcase
      %w[asc desc].include?(dir) ? dir : (@sort_default_direction || "desc")
    end
end
