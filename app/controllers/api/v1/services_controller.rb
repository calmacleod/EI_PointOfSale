module Api
  module V1
    class ServicesController < BaseController
      def sync
        authorize! :read, Service

        services = Service.kept
                          .includes(:tax_code)
                          .select(:id, :code, :name, :price, :description,
                                  :tax_code_id, :sales_count, :created_at, :updated_at)

        if params[:since].present?
          since = Time.zone.parse(params[:since]) rescue nil
          services = services.where("services.updated_at > ?", since) if since
        end

        render json: {
          synced_at: Time.current.iso8601,
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
