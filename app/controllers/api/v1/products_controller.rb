module Api
  module V1
    class ProductsController < BaseController
      def sync
        render_catalog_sync(Product)
      end
    end
  end
end
