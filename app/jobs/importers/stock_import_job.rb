# frozen_string_literal: true

module Importers
  class StockImportJob < ApplicationJob
    queue_as :default

    def perform(data_import_id)
      data_import = DataImport.find(data_import_id)
      return if data_import.completed? || data_import.processing?

      csv_content = data_import.file.download
      Importers::StockImporter.new(data_import).execute(csv_content)
    rescue => e
      data_import&.update!(status: "failed", errors_log: [ { error: e.message } ])
      Rails.logger.error("StockImportJob failed for import #{data_import_id}: #{e.message}")
      raise
    end
  end
end
