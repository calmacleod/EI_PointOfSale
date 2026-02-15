# frozen_string_literal: true

class CustomersController < ApplicationController
  load_and_authorize_resource

  def index
    scope = @customers.kept.includes(:added_by).order(:name)
    scope = scope.search(sanitize_search_query(params[:q])) if params[:q].present?
    scope = scope.where(active: true) if params[:filter] == "active"
    scope = scope.where(active: false) if params[:filter] == "inactive"
    scope = apply_date_filters(scope)
    @pagy, @customers = pagy(:offset, scope)
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
