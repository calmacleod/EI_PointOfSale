module Api
  module V1
    class BaseController < ApplicationController
      rescue_from CanCan::AccessDenied do
        render json: { error: "Forbidden" }, status: :forbidden
      end

      rescue_from Offline::CatalogSync::InvalidCursor do
        render json: { error: "Invalid or expired sync cursor; restart the sync" }, status: :bad_request
      end

      private

        def render_catalog_sync(model)
          authorize! :read, model
          render json: Offline::CatalogSync.new(model, since: params[:since], page_size: params[:page_size], cursor: params[:cursor]).call
        end
    end
  end
end
