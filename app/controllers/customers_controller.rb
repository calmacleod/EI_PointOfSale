# frozen_string_literal: true

class CustomersController < ApplicationController
  include Filterable

  load_and_authorize_resource

  def index
    @pagy, @customers = filter_and_paginate(
      @customers.kept.includes(:added_by),
      sort_allowed: %w[name member_number email active created_at],
      sort_default: "name", sort_default_direction: "asc",
      filters: ->(scope) {
        scope = scope.where(active: true) if params[:filter] == "active"
        scope = scope.where(active: false) if params[:filter] == "inactive"
        scope
      }
    )
  end

  def new
  end

  def create
    @customer.added_by = current_user
    if @customer.save
      redirect_to customers_path, notice: "Customer created."
    else
      render :new, status: :unprocessable_entity
    end
  end

  def show
  end

  def edit
  end

  def update
    if @customer.update(customer_params)
      redirect_to customers_path, notice: "Customer updated."
    else
      render :edit, status: :unprocessable_entity
    end
  end

  def destroy
    @customer.discard
    redirect_to customers_path, notice: "Customer removed."
  end

  private

    def customer_params
      params.require(:customer).permit(
        :name,
        :member_number,
        :phone,
        :email,
        :address_line1,
        :address_line2,
        :city,
        :province,
        :postal_code,
        :country,
        :account_status,
        :date_of_birth,
        :joining_date,
        :active,
        :notes,
        :alert
      )
    end
end
