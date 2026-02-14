module AdminArea
  class SettingsController < ApplicationController
    before_action :require_admin

    def show
      # Placeholder settings page (wire up persistence later)
    end

    private

      def require_admin
        return if current_user.is_a?(::Admin)

        raise CanCan::AccessDenied
      end
  end
end
