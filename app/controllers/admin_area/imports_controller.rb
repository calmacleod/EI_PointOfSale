# frozen_string_literal: true

module AdminArea
  class ImportsController < ApplicationController
    before_action :require_admin

    def new
      @data_import = DataImport.new
      @recent_imports = DataImport.recent.limit(10)
    end

    def create
      unless params[:file].present?
        redirect_to new_admin_import_path, alert: "Please select a CSV file."
        return
      end

      csv_content = params[:file].read.force_encoding("UTF-8")
      @data_import = DataImport.new(
        file_name: params[:file].original_filename,
        imported_by: current_user
      )
      @data_import.file.attach(params[:file])

      if params[:preview].present?
        importer = Importers::StockImporter.new(@data_import)
        @preview = importer.preview(csv_content)
        @data_import.total_rows = @preview[:total_rows]
        @data_import.save!
        render :preview
      else
        @data_import.save!
        Importers::StockImportJob.perform_later(@data_import.id)
        redirect_to admin_import_path(@data_import), notice: "Import started. Processing #{@data_import.file_name}..."
      end
    end

    def show
      @data_import = DataImport.find(params[:id])
    end

    def execute
      @data_import = DataImport.find(params[:id])

      if @data_import.status == "pending" && @data_import.file.attached?
        Importers::StockImportJob.perform_later(@data_import.id)
        redirect_to admin_import_path(@data_import), notice: "Import started. Processing #{@data_import.file_name}..."
      else
        redirect_to admin_import_path(@data_import), alert: "This import cannot be executed."
      end
    end

    private

      def require_admin
        redirect_to root_path, alert: "Not authorized." unless current_user&.is_a?(Admin)
      end
  end
end
