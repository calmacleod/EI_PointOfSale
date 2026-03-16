# frozen_string_literal: true

class AddGinIndexToPgSearchDocuments < ActiveRecord::Migration[8.1]
  def change
    enable_extension "pg_trgm" unless extension_enabled?("pg_trgm")
    add_index :pg_search_documents, :content, using: :gin,
              opclass: :gin_trgm_ops,
              name: "index_pg_search_documents_on_content_trgm"
  end
end
