# frozen_string_literal: true

module AdminArea
  class DataExportsController < BaseController
    def show
      @export_tables = DatabaseExportService::EXPORT_TABLES
    end

    def create
      timestamp = Time.current.strftime("%Y%m%d_%H%M%S")
      filename = "ei_pos_export_#{timestamp}.xlsx"

      xlsx_data = DatabaseExportService.generate

      send_data xlsx_data,
        filename: filename,
        type: "application/vnd.openxmlformats-officedocument.spreadsheetml.sheet",
        disposition: "attachment"
    end
  end
end
