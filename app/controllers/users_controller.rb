class UsersController < ApplicationController
  load_and_authorize_resource

  def index
    scope = @users.order(:email_address)
    scope = scope.search(params[:q]) if params[:q].present?
    scope = apply_date_filters(scope)
    @pagy, @users = pagy(:offset, scope)
  end

  def show
  end

  def edit
  end

  def update
    if @user.update(user_params)
      redirect_to users_path, notice: "User updated."
    else
      render :edit, status: :unprocessable_entity
    end
  end

  private

    def user_params
      base = [
        :name,
        :email_address,
        :phone,
        :notes,
        :password,
        :password_confirmation
      ]

      # Only admins can change role or activation state.
      if current_user.is_a?(Admin)
        base += %i[type active]
      end

      params.require(:user).permit(*base)
    end
end
