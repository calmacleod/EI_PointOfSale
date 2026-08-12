module Api
  module V1
    class CustomersController < BaseController
      def sync
        authorize! :read, Customer

        customers = Customer.kept
                            .select(:id, :name, :member_number, :email, :phone,
                                    :address_line1, :address_line2, :city, :province,
                                    :postal_code, :country, :notes, :alert,
                                    :discount_id, :tax_code_id, :created_at, :updated_at)

        customers = customers.where("customers.updated_at > ?", sync_since) if sync_since

        render json: {
          synced_at: Time.current.iso8601,
          deleted_ids: deleted_ids_since(Customer),
          customers: customers.map { |c|
            {
              id:            c.id,
              name:          c.name,
              member_number: c.member_number,
              email:         c.email,
              phone:         c.phone,
              address_line1: c.address_line1,
              address_line2: c.address_line2,
              city:          c.city,
              province:      c.province,
              postal_code:   c.postal_code,
              country:       c.country,
              notes:         c.notes,
              alert:         c.alert,
              discount_id:   c.discount_id,
              tax_code_id:   c.tax_code_id,
              created_at:    c.created_at.iso8601,
              updated_at:    c.updated_at.iso8601
            }
          }
        }
      end
    end
  end
end
