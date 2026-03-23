module Api
  module V1
    class ProductsController < BaseController
      def sync
        authorize! :read, Product

        products = Product.kept
                          .includes(:tax_code)
                          .select(:id, :code, :name, :selling_price,
                                  :stock_level, :tax_code_id, :updated_at)

        if params[:since].present?
          since = Time.zone.parse(params[:since]) rescue nil
          products = products.where("products.updated_at > ?", since) if since
        end

        render json: {
          synced_at: Time.current.iso8601,
          products: products.map { |p|
            {
              id:            p.id,
              code:          p.code,
              name:          p.name,
              selling_price: p.selling_price.to_s,
              stock_level:   p.stock_level,
              tax_code:      p.tax_code&.code,
              tax_rate:      p.tax_code&.rate&.to_s,
              updated_at:    p.updated_at.iso8601
            }
          }
        }
      end
    end
  end
end
