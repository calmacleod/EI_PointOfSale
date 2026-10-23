# frozen_string_literal: true

module Offline
  # Read typed scalar values instead of instantiating the catalog and each of its
  # associations. Keep the public JSON field types identical to the original API.
  class CatalogSerializer
    FIELDS = {
      Product => %i[id code name selling_price purchase_price stock_level reorder_level order_quantity unit_cost items_per_unit supplier_reference notes product_url sync_to_shopify sales_count last_restocked_at created_at updated_at],
      Service => %i[id code name price description sales_count created_at updated_at],
      Customer => %i[id name member_number email phone address_line1 address_line2 city province postal_code country notes alert discount_id tax_code_id created_at updated_at],
      TaxCode => %i[id code name rate exemption_type province_code notes created_at updated_at]
    }.freeze
    ASSOCIATIONS = {
      Product => { tax_code: [ TaxCode, :code ], tax_rate: [ TaxCode, :rate ], supplier: [ Supplier, :name ], product_group: [ ProductGroup, :name ] },
      Service => { tax_code: [ TaxCode, :code ], tax_rate: [ TaxCode, :rate ] }
    }.freeze
    JOINS = { Product => %i[tax_code supplier product_group], Service => [ :tax_code ] }.freeze

    def self.rows(scope)
      model = scope.klass
      keys = FIELDS.fetch(model) + [ :discarded_at ]
      columns = keys.map { |key| model.arel_table[key] }
      # @type var associations: Hash[Symbol, [untyped, Symbol]]
      associations = ASSOCIATIONS.fetch(model, {})
      associations.each_pair do |key, field|
        keys << key
        columns << field[0].arel_table[field[1]]
      end
      scope = scope.left_joins(*JOINS.fetch(model)) if JOINS.key?(model)
      scope.pluck(*columns).map do |values|
        {}.tap { |row| keys.each_index { |index| row[keys[index]] = values[index] } }
      end
    end

    def self.record(row)
      row.except(:discarded_at).tap do |record|
        %i[selling_price price rate].each { |key| record[key] = record[key].to_s if record.key?(key) }
        %i[purchase_price unit_cost tax_rate].each { |key| record[key] = record[key]&.to_s if record.key?(key) }
        %i[created_at updated_at last_restocked_at].each do |key|
          record[key] = record[key]&.in_time_zone&.iso8601 if record.key?(key)
        end
      end
    end
  end
end
