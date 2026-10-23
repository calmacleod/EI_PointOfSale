module Api
  module V1
    class ServicesController < BaseController
      def sync
        render_catalog_sync(Service)
      end
    end
  end
end
