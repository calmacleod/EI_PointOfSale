module Api
  module V1
    class BaseController < ApplicationController
      rescue_from CanCan::AccessDenied do
        render json: { error: "Forbidden" }, status: :forbidden
      end

      private

        def sync_since
          return @sync_since if defined?(@sync_since)

          @sync_since = Time.zone.parse(params[:since]) if params[:since].present?
        rescue ArgumentError, TypeError
          @sync_since = nil
        end

        def deleted_ids_since(model)
          return [] unless sync_since

          model.discarded.where("updated_at > ?", sync_since).pluck(:id)
        end
    end
  end
end
