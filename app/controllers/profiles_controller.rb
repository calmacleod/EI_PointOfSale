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
      render_inertia_page(action: :edit, status: :unprocessable_entity)
    end
  end

  def update_display_preferences
    @user = Current.user
    authorize! :update, @user

    @user.update!(display_preferences_params)
    head :no_content
  end

  private

    def profile_params
      params.require(:user).permit(
        :name,
        :email_address,
        :phone,
        :notes,
        :password,
        :password_confirmation,
        :theme,
        :font_size,
        :sidebar_collapsed,
        dashboard_metric_keys: []
      )
    end

    def display_preferences_params
      params.require(:user).permit(:sidebar_collapsed)
    end
end
