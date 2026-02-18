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

  private

    def enqueue_pg_search_update
      return unless pg_search_multisearchable_enabled?

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
end
