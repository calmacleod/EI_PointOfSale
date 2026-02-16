# frozen_string_literal: true

module AdminArea
  class UsersController < BaseController
    include Filterable

    load_and_authorize_resource

    def index
      @filter_config = FilterConfig.new(:users, admin_users_path,
                                        sort_default: "email_address", sort_default_direction: "asc",
                                        search_placeholder: "Search users...") do |f|
        f.select   :type,   label: "Type",   options: [ %w[Admin Admin], %w[Common Common] ]
        f.boolean  :active, label: "Active"
        f.date_range :created_at, label: "Created"

        f.column :name,          label: "Name",    default: true,  sortable: true
        f.column :email_address, label: "Email",   default: true,  sortable: true
        f.column :type,          label: "Type",    default: true,  sortable: true
        f.column :phone,         label: "Phone",   default: false
        f.column :active,        label: "Active",  default: true
        f.column :created_at,    label: "Created", default: true,  sortable: true
        f.column :updated_at,    label: "Updated", default: false, sortable: true
      end
      @saved_queries = current_user.saved_queries.for_resource("users")

      @pagy, @users = filter_and_paginate(
        @users,
        config: @filter_config
      )
    end

    def show
    end

    def new
    end

    def create
      if @user.save
        redirect_to admin_user_path(@user), notice: "User created."
      else
        render :new, status: :unprocessable_entity
      end
    end

    def edit
    end

    def update
      if @user.update(user_params)
        redirect_to admin_users_path, notice: "User updated."
      else
        render :edit, status: :unprocessable_entity
      end
    end

    private

      def user_params
        params.require(:user).permit(
          :name,
          :email_address,
          :phone,
          :notes,
          :password,
          :password_confirmation,
          :type,
          :active
        )
      end
  end
end
