# frozen_string_literal: true

class AddTsvectorToPgSearchDocuments < ActiveRecord::Migration[8.1]
  def up
    execute <<~SQL
      ALTER TABLE pg_search_documents
        ADD COLUMN content_tsv tsvector
        GENERATED ALWAYS AS (to_tsvector('simple', coalesce(content, ''))) STORED;

      CREATE INDEX index_pg_search_documents_on_content_tsv
        ON pg_search_documents USING GIN (content_tsv);
    SQL
  end

  def down
    execute "DROP INDEX index_pg_search_documents_on_content_tsv"
    remove_column :pg_search_documents, :content_tsv
  end
end
