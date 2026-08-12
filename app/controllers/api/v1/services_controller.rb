module Api
  module V1
    class ServicesController < BaseController
      def sync
        authorize! :read, Service

        services = Service.kept
                          .includes(:tax_code)
                          .select(:id, :code, :name, :price, :description,
                                  :tax_code_id, :sales_count, :created_at, :updated_at)

        services = services.where("services.updated_at > ?", sync_since) if sync_since

        render json: {
          synced_at: Time.current.iso8601,
          deleted_ids: deleted_ids_since(Service),
          services: services.map { |s|
            {
              id:          s.id,
              code:        s.code,
              name:        s.name,
              price:       s.price.to_s,
              description: s.description,
              tax_code:    s.tax_code&.code,
              tax_rate:    s.tax_code&.rate&.to_s,
              sales_count: s.sales_count,
              created_at:  s.created_at.iso8601,
              updated_at:  s.updated_at.iso8601
            }
          }
        }
      end
    end
  end
end
