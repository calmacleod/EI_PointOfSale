# frozen_string_literal: true

class CustomersController < ApplicationController
  include Filterable

  load_and_authorize_resource except: [ :search ]

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
    respond_to do |format|
      format.html { fresh_when @customer }
      format.json {
        render json: {
          id: @customer.id,
          name: @customer.name,
          member_number: @customer.member_number,
          phone: @customer.phone,
          email: @customer.email,
          tax_code: @customer.tax_code&.name,
          status_card_number: @customer.status_card_number,
          alert: @customer.alert
        }
      }
    end
  end

  def search
    authorize! :search, Customer

    @query = params[:q].to_s.strip

    if @query.length >= 1
      @customers = Customer.kept.search(@query)

      filter = params[:filter].to_s
      @customers = @customers.where(active: true) if filter == "active"
      @customers = @customers.where.not(tax_code_id: nil) if filter == "tax_exempt"

      @customers = @customers.includes(:tax_code).limit(15)
    end

    respond_to do |format|
      format.turbo_stream
      format.json do
        results = (@customers || []).map do |c|
          {
            id: c.id, name: c.name, member_number: c.member_number,
            phone: c.phone, email: c.email, active: c.active?,
            has_tax_code: c.tax_code.present?, tax_code_name: c.tax_code&.name,
            has_alert: c.alert.present?
          }
        end
        render json: { results: results }
      end
    end
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
        :alert,
        :discount_id
      )
    end
end
