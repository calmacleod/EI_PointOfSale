# frozen_string_literal: true

module AdminArea
  class ReportsController < BaseController
    include Filterable

    before_action :set_report, only: %i[show export_pdf export_excel destroy]

    def index
      @templates = ReportTemplate.all

      @pagy, @reports = filter_and_paginate(
        Report.includes(:generated_by),
        sort_allowed: %w[title report_type status created_at completed_at],
        filters: ->(scope) {
          scope = scope.by_status(params[:status])
          scope = scope.by_report_type(params[:report_type])
          scope
        }
      )
    end

    def new
      @template = ReportTemplate.find(params[:template])
      redirect_to admin_reports_path, alert: "Unknown report template." unless @template
    end

    def create
      template = ReportTemplate.find(report_params[:report_type])

      unless template
        redirect_to admin_reports_path, alert: "Unknown report template."
        return
      end

      @report = Report.new(
        report_type: template.key,
        title: "#{template.title} — #{Time.current.strftime('%b %d, %Y %l:%M %p')}",
        parameters: report_params[:parameters]&.to_unsafe_h || {},
        generated_by: current_user
      )

      if @report.save
        GenerateReportJob.perform_later(@report.id)
        redirect_to admin_report_path(@report), notice: "Report queued for generation."
      else
        @template = template
        render :new, status: :unprocessable_entity
      end
    end

    def show
      @template = @report.template
    end

    def export_pdf
      unless @report.completed?
        redirect_to admin_report_path(@report), alert: "Report is not ready for export."
        return
      end

      pdf_data = ReportPdfExporter.generate(@report)

      send_data pdf_data,
        filename: pdf_filename,
        type: "application/pdf",
        disposition: "attachment"
    end

    def export_excel
      unless @report.completed?
        redirect_to admin_report_path(@report), alert: "Report is not ready for export."
        return
      end

      xlsx_data = ReportExcelExporter.generate(@report)

      send_data xlsx_data,
        filename: excel_filename,
        type: "application/vnd.openxmlformats-officedocument.spreadsheetml.sheet",
        disposition: "attachment"
    end

    def destroy
      @report.destroy
      redirect_to admin_reports_path, notice: "Report deleted."
    end

    private

      def set_report
        @report = Report.find(params[:id])
      end

      def report_params
        params.require(:report).permit(:report_type, parameters: {})
      end

      def pdf_filename
        "#{@report.report_type}_#{@report.id}_#{@report.created_at.strftime('%Y%m%d')}.pdf"
      end

      def excel_filename
        "#{@report.report_type}_#{@report.id}_#{@report.created_at.strftime('%Y%m%d')}.xlsx"
      end
  end
end
