module Api
  module V1
    class TaxCodesController < BaseController
      def sync
        authorize! :read, TaxCode

        tax_codes = TaxCode.kept
                           .select(:id, :code, :name, :rate, :exemption_type,
                                   :province_code, :notes, :created_at, :updated_at)

        if params[:since].present?
          since = Time.zone.parse(params[:since]) rescue nil
          tax_codes = tax_codes.where("tax_codes.updated_at > ?", since) if since
        end

        render json: {
          synced_at: Time.current.iso8601,
          tax_codes: tax_codes.map { |t|
            {
              id:             t.id,
              code:           t.code,
              name:           t.name,
              rate:           t.rate.to_s,
              exemption_type: t.exemption_type,
              province_code:  t.province_code,
              notes:          t.notes,
              created_at:     t.created_at.iso8601,
              updated_at:     t.updated_at.iso8601
            }
          }
        }
      end
    end
  end
end
