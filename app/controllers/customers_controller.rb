# frozen_string_literal: true

class CustomersController < ApplicationController
  include Filterable

  load_and_authorize_resource

  def index
    @filter_config = FilterConfig.new(:customers, customers_path,
                                      sort_default: "name", sort_default_direction: "asc",
                                      search_placeholder: "Search customers...") do |f|
      f.boolean    :active,     label: "Active"
      f.date_range :created_at, label: "Created"
      f.date_range :updated_at, label: "Updated"

      f.column :name,          label: "Customer",  default: true,  sortable: true
      f.column :member_number, label: "Member #",   default: true,  sortable: true
      f.column :phone,         label: "Phone",      default: true
      f.column :email,         label: "Email",      default: true
      f.column :city,          label: "City",       default: false
      f.column :province,      label: "Province",   default: false
      f.column :active,        label: "Status",     default: true,  sortable: true
      f.column :created_at,    label: "Created",    default: true,  sortable: true
      f.column :updated_at,    label: "Updated",    default: false, sortable: true
    end
    @saved_queries = current_user.saved_queries.for_resource("customers")

    @pagy, @customers = filter_and_paginate(
      @customers.kept.includes(:added_by),
      config: @filter_config
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
    fresh_when @customer
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
