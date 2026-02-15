# frozen_string_literal: true

class ServicesController < ApplicationController
  include Filterable

  load_and_authorize_resource

  def index
    @pagy, @services = filter_and_paginate(
      @services.kept.includes(:tax_code),
      sort_allowed: %w[name code price created_at],
      sort_default: "name", sort_default_direction: "asc"
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
