# frozen_string_literal: true

module AdminArea
  class ReceiptTemplatesController < BaseController
    include Filterable

    before_action :set_receipt_template, only: %i[show edit update destroy activate preview]

    def index
      @filter_config = FilterConfig.new(:receipt_templates, admin_receipt_templates_path,
                                        sort_default: "name", sort_default_direction: "asc",
                                        search: false) do |f|
        f.boolean :active,         label: "Active"
        f.select  :paper_width_mm, label: "Paper Width", options: [ [ "58mm", "58" ], [ "80mm", "80" ] ]
        f.date_range :created_at,  label: "Created"

        f.column :name,           label: "Name",       default: true, sortable: true
        f.column :paper_width_mm, label: "Paper Width", default: true, sortable: true
        f.column :chars_per_line, label: "Chars/Line", default: true
        f.column :active,         label: "Active",     default: true, sortable: true
        f.column :created_at,     label: "Created",    default: true, sortable: true
      end
      @saved_queries = current_user.saved_queries.for_resource("receipt_templates")

      @pagy, @receipt_templates = filter_and_paginate(
        ReceiptTemplate.all,
        config: @filter_config
      )
    end

    def new
      @receipt_template = ReceiptTemplate.new(paper_width_mm: 80)
      @store = Store.current
    end

    def create
      @receipt_template = ReceiptTemplate.new(receipt_template_params)
      if @receipt_template.save
        redirect_to admin_receipt_templates_path, notice: "Receipt template created."
      else
        @store = Store.current
        render :new, status: :unprocessable_entity
      end
    end

    def show
      @store = Store.current
      @preview_lines = @receipt_template.formatted_preview(store: @store)
    end

    def edit
      @store = Store.current
    end

    def update
      if @receipt_template.update(receipt_template_params)
        redirect_to admin_receipt_template_path(@receipt_template), notice: "Receipt template updated."
      else
        @store = Store.current
        render :edit, status: :unprocessable_entity
      end
    end

    def destroy
      @receipt_template.destroy
      redirect_to admin_receipt_templates_path, notice: "Receipt template deleted."
    end

    def activate
      @receipt_template.activate!
      redirect_to admin_receipt_templates_path, notice: "\"#{@receipt_template.name}\" is now the active template."
    end

    def preview
      @store = Store.current
      @preview_lines = @receipt_template.formatted_preview(store: @store)
      render partial: "receipt_preview", locals: { lines: @preview_lines, receipt_template: @receipt_template }
    end

    private

      def set_receipt_template
        @receipt_template = ReceiptTemplate.find(params[:id])
      end

      def receipt_template_params
        params.require(:receipt_template).permit(
          :name, :paper_width_mm, :show_store_name, :show_store_address,
          :show_store_phone, :show_store_email, :show_logo, :header_text,
          :footer_text, :show_date_time, :show_cashier_name
        )
      end
  end
end
