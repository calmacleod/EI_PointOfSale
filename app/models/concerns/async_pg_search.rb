# frozen_string_literal: true

# Handles async updates to PgSearch documents for models using multisearchable.
# Include this concern in any model that uses `multisearchable` to defer
# search index updates to a background job.
#
# Example:
#   class Product < ApplicationRecord
#     include PgSearch::Model
#     include AsyncPgSearch
#
#     multisearchable against: [:name], if: :active?
#   end
#
module AsyncPgSearch
  extend ActiveSupport::Concern

  included do
    after_commit :enqueue_pg_search_update, on: [ :create, :update ]
    after_commit :destroy_pg_search_document, on: :destroy
  end

  class_methods do
    def multisearchable(...)
      super.tap do
        skip_callback :save, :after, :update_pg_search_document
      end
    end
  end

  private

    def enqueue_pg_search_update
      return unless searchable_columns_changed?

      PgSearchUpdateJob.perform_later(self.class.name, id)
    end

    def destroy_pg_search_document
      pg_search_document&.destroy!
    end

    def pg_search_multisearchable_enabled?
      return false unless respond_to?(:pg_search_document)

      # Check if the 'if' condition is met
      condition = self.class.pg_search_multisearchable_options[:if]
      return true if condition.nil?

      instance_eval(&condition)
    end

    def searchable_columns_changed?
      # Always index on create
      return true if transaction_include_any_action?([ :create ])

      options = self.class.pg_search_multisearchable_options
      against = Array(options[:against])
      changed_columns = saved_changes.keys

      # Check if any direct columns changed
      return true if (changed_columns & against.map(&:to_s)).any?

      # Check associated columns (e.g., customer.name)
      associated = options[:associated_against] || {}
      associated.each do |association, columns|
        association_id = "#{association}_id"
        return true if changed_columns.include?(association_id)
      end

      # These columns drive the conditional `if:` clauses used by the
      # multisearchable models in this application.
      (changed_columns & %w[discarded_at status]).any?
    end
end
