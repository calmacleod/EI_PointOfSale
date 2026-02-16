# frozen_string_literal: true

module AdminArea
  class UsersController < BaseController
    include Filterable

    load_and_authorize_resource

    def index
      @pagy, @users = filter_and_paginate(
        @users,
        sort_allowed: %w[name email_address type created_at],
        sort_default: "email_address", sort_default_direction: "asc"
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
