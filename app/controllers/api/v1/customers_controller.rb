module Api
  module V1
    class CustomersController < BaseController
      def sync
        render_catalog_sync(Customer)
      end
    end
  end
end
