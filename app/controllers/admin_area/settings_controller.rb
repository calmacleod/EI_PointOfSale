# frozen_string_literal: true

module AdminArea
  class SettingsController < BaseController
    def show
      @store = Store.current
    end

    def update
      @store = Store.current
      if @store.update(store_params)
        redirect_to admin_settings_path, notice: "Settings saved."
      else
        render :show, status: :unprocessable_entity
      end
    end

    private

      def store_params
        params.require(:store).permit(
          :name, :phone, :email,
          :address_line1, :address_line2, :city, :province, :postal_code, :country
        )
      end
  end
end
