# frozen_string_literal: true

class PgSearchUpdateJob < ApplicationJob
  queue_as :default

  discard_on ActiveRecord::RecordNotFound

  def perform(searchable_type, searchable_id)
    searchable = searchable_type.constantize.find(searchable_id)
    return unless searchable.respond_to?(:update_pg_search_document)

    # Only update if the record still matches the multisearchable condition
    if searchable.class.pg_search_multisearchable_options[:if].nil? ||
       searchable.instance_eval(&searchable.class.pg_search_multisearchable_options[:if])
      searchable.update_pg_search_document
    else
      # Remove document if it no longer meets the condition
      PgSearch::Document.where(searchable: searchable).destroy_all
    end
  end
end
