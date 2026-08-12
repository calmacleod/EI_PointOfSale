module Api
  module V1
    class TaxCodesController < BaseController
      def sync
        authorize! :read, TaxCode

        tax_codes = TaxCode.kept
                           .select(:id, :code, :name, :rate, :exemption_type,
                                   :province_code, :notes, :created_at, :updated_at)

        tax_codes = tax_codes.where("tax_codes.updated_at > ?", sync_since) if sync_since

        render json: {
          synced_at: Time.current.iso8601,
          deleted_ids: deleted_ids_since(TaxCode),
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
