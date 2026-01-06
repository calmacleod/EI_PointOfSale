class ProfilesController < ApplicationController
  def edit
    @user = Current.user
    authorize! :update, @user
  end

  def update
    @user = Current.user
    authorize! :update, @user

    if @user.update(profile_params)
      redirect_to edit_profile_path, notice: "Profile updated."
    else
      render :edit, status: :unprocessable_entity
    end
  end

  private

    def profile_params
      params.require(:user).permit(
        :name,
        :email_address,
        :phone,
        :notes,
        :password,
        :password_confirmation
      )
    end
end


