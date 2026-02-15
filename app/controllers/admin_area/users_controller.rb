# frozen_string_literal: true

module AdminArea
  class UsersController < BaseController
    include FilterableByDate

    load_and_authorize_resource

    def index
      scope = @users.order(:email_address)
      scope = scope.search(sanitize_search_query(params[:q])) if params[:q].present?
      scope = apply_date_filters(scope)
      @pagy, @users = pagy(:offset, scope)
    end

    def show
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
