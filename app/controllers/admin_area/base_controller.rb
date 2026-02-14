# frozen_string_literal: true

module AdminArea
  class BaseController < ApplicationController
    before_action :require_admin

    private

      def require_admin
        return if current_user.is_a?(::Admin)

        raise CanCan::AccessDenied
      end
  end
end
