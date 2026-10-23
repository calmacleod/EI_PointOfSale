module Api
  module V1
    class TaxCodesController < BaseController
      def sync
        render_catalog_sync(TaxCode)
      end
    end
  end
end
