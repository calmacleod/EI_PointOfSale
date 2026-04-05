module Api
  module V1
    class ProductsController < BaseController
      def sync
        authorize! :read, Product

        products = Product.kept
                          .includes(:tax_code, :supplier, :product_group)
                          .select(:id, :code, :name, :selling_price, :purchase_price,
                                  :stock_level, :reorder_level, :order_quantity,
                                  :unit_cost, :items_per_unit,
                                  :supplier_reference, :notes, :product_url,
                                  :tax_code_id, :supplier_id, :product_group_id,
                                  :sync_to_shopify, :sales_count,
                                  :last_restocked_at, :created_at, :updated_at)

        if params[:since].present?
          since = Time.zone.parse(params[:since]) rescue nil
          products = products.where("products.updated_at > ?", since) if since
        end

        render json: {
          synced_at: Time.current.iso8601,
          products: products.map { |p|
            {
              id:                p.id,
              code:              p.code,
              name:              p.name,
              selling_price:     p.selling_price.to_s,
              purchase_price:    p.purchase_price&.to_s,
              stock_level:       p.stock_level,
              reorder_level:     p.reorder_level,
              order_quantity:    p.order_quantity,
              unit_cost:         p.unit_cost&.to_s,
              items_per_unit:    p.items_per_unit,
              supplier_reference: p.supplier_reference,
              notes:             p.notes,
              product_url:       p.product_url,
              tax_code:          p.tax_code&.code,
              tax_rate:          p.tax_code&.rate&.to_s,
              supplier:          p.supplier&.name,
              product_group:     p.product_group&.name,
              sync_to_shopify:   p.sync_to_shopify,
              sales_count:       p.sales_count,
              last_restocked_at: p.last_restocked_at&.iso8601,
              created_at:        p.created_at.iso8601,
              updated_at:        p.updated_at.iso8601
            }
          }
        }
      end
    end
  end
end
