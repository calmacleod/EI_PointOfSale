class ProfilesController < ApplicationController
  def edit
    @user = Current.user
    authorize! :update, @user
  end

  def update
    @user = Current.user
    authorize! :update, @user

    if @user.update(profile_params)
      respond_to do |format|
        format.turbo_stream do
          render turbo_stream: [
            turbo_stream.update("flash_container", partial: "shared/flash", locals: { flash: { notice: "Profile updated." } }),
            turbo_stream.update("profile_form", partial: "profiles/form", locals: { user: @user }),
            turbo_stream.append_all("body") { "<script>document.documentElement.setAttribute('data-theme','#{ERB::Util.json_escape(@user.theme)}');document.documentElement.setAttribute('data-font-size','#{ERB::Util.json_escape(@user.font_size)}');</script>".html_safe }
          ], status: :ok
        end
        format.html { redirect_to edit_profile_path, notice: "Profile updated." }
      end
    else
      render :edit, status: :unprocessable_entity
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
        :sidebar_collapsed
      )
    end

    def display_preferences_params
      params.require(:user).permit(:sidebar_collapsed)
    end
end
