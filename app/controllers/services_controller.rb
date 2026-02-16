# frozen_string_literal: true

class ServicesController < ApplicationController
  include Filterable

  load_and_authorize_resource

  def index
    @filter_config = FilterConfig.new(:services, services_path,
                                      sort_default: "name", sort_default_direction: "asc",
                                      search_placeholder: "Search services...") do |f|
      f.association  :tax_code_id, label: "Tax Code", collection: -> { TaxCode.kept.order(:code) }, display: :code
      f.number_range :price,       label: "Price"
      f.date_range   :created_at,  label: "Created"
      f.date_range   :updated_at,  label: "Updated"

      f.column :name,        label: "Service",     default: true,  sortable: true
      f.column :code,        label: "Code",        default: true,  sortable: true
      f.column :price,       label: "Price",       default: true,  sortable: true
      f.column :tax_code,    label: "Tax",         default: true
      f.column :description, label: "Description", default: false
      f.column :created_at,  label: "Created",     default: true,  sortable: true
      f.column :updated_at,  label: "Updated",     default: false, sortable: true
    end
    @saved_queries = current_user.saved_queries.for_resource("services")

    @pagy, @services = filter_and_paginate(
      @services.kept.includes(:tax_code),
      config: @filter_config
    )
  end

  def new
  end

  def create
    @service.added_by = current_user
    if @service.save
      redirect_to services_path, notice: "Service created."
    else
      render :new, status: :unprocessable_entity
    end
  end

  def show
  end

  def edit
  end

  def update
    if @service.update(service_params)
      redirect_to services_path, notice: "Service updated."
    else
      render :edit, status: :unprocessable_entity
    end
  end

  def destroy
    @service.discard
    redirect_to services_path, notice: "Service removed."
  end

  private

    def service_params
      params.require(:service).permit(:name, :code, :description, :price, :tax_code_id)
    end
end
