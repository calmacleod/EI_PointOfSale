module Api
  module V1
    class BaseController < ApplicationController
      rescue_from CanCan::AccessDenied do
        render json: { error: "Forbidden" }, status: :forbidden
      end
    end
  end
end
