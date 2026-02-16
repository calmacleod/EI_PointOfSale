# frozen_string_literal: true

require "csv"

module Importers
  class StockImporter
    COLUMN_MAP = {
      "Stock_Code"     => :code,
      "Product_Name"   => :name,
      "Selling_Price"  => :selling_price,
      "Purchase_Price" => :purchase_price,
      "Stock_Level"    => :stock_level,
      "Reorder_Level"  => :reorder_level,
      "Order2_Level"   => :order_quantity,
      "OUnit_Cost"     => :unit_cost,
      "Items_Unit"     => :items_per_unit,
      "Supp_Ref"       => :supplier_reference,
      "Addit_Info"     => :notes
    }.freeze

    attr_reader :data_import

    def initialize(data_import)
      @data_import = data_import
    end

    # Returns a preview hash without persisting anything.
    def preview(csv_content)
      rows = parse_csv(csv_content)

      categories = rows.map { |r| r["Stock_Cat"] }.compact_blank.uniq.sort
      suppliers = rows.map { |r| r["Supplier"] }.compact_blank.uniq.sort
      duplicate_codes = rows.group_by { |r| r["Stock_Code"] }
                            .select { |_, v| v.size > 1 }
                            .keys
      blank_codes = rows.count { |r| r["Stock_Code"].blank? }

      {
        total_rows: rows.size,
        categories: categories,
        category_count: categories.size,
        suppliers: suppliers,
        supplier_count: suppliers.size,
        duplicate_codes: duplicate_codes.size,
        blank_codes: blank_codes,
        sample_rows: rows.first(5).map { |r| r.to_h }
      }
    end

    # Performs the full import, updating the data_import record with progress.
    def execute(csv_content)
      rows = parse_csv(csv_content)

      # Deduplicate by code, keeping the last occurrence
      rows_by_code = {}
      rows.each do |row|
        code = row["Stock_Code"]&.strip
        next if code.blank?
        rows_by_code[code] = row
      end
      unique_rows = rows_by_code.values

      data_import.update!(
        status: "processing",
        total_rows: unique_rows.size,
        processed_rows: 0,
        created_count: 0,
        updated_count: 0,
        error_count: 0,
        errors_log: []
      )

      # Pre-create suppliers and categories
      supplier_map = build_supplier_map(rows)
      category_map = build_category_map(rows)
      tax_code_map = build_tax_code_map

      created = 0
      updated = 0
      errors = 0
      error_log = []

      unique_rows.each_with_index do |row, index|
        import_row(row, supplier_map, category_map, tax_code_map)
        if Product.exists?(code: row["Stock_Code"].strip)
          # We can't easily tell if it was created or updated without more logic,
          # so we'll track based on whether it existed before
        end
      rescue => e
        errors += 1
        error_log << { row: index + 1, code: row["Stock_Code"], error: e.message }
      ensure
        data_import.update_columns(
          processed_rows: index + 1,
          error_count: errors,
          errors_log: error_log
        ) if (index + 1) % 100 == 0 || index == unique_rows.size - 1
      end

      # Final count
      data_import.update!(
        status: "completed",
        processed_rows: unique_rows.size,
        created_count: data_import.created_count,
        updated_count: data_import.updated_count,
        error_count: errors,
        errors_log: error_log,
        completed_at: Time.current
      )
    rescue => e
      data_import.update!(
        status: "failed",
        errors_log: (data_import.errors_log || []) + [ { error: e.message } ]
      )
      raise
    end

    private

      def parse_csv(content)
        CSV.parse(content, headers: true, liberal_parsing: true)
      end

      def import_row(row, supplier_map, category_map, tax_code_map)
        code = row["Stock_Code"]&.strip
        return if code.blank?

        product = Product.find_or_initialize_by(code: code)
        was_new = product.new_record?

        attrs = {}
        COLUMN_MAP.each do |csv_col, model_attr|
          value = row[csv_col]
          next if value.nil?
          attrs[model_attr] = value.is_a?(String) ? value.strip : value
        end

        # Numeric conversions
        attrs[:selling_price] = attrs[:selling_price].to_d if attrs[:selling_price].present?
        attrs[:purchase_price] = attrs[:purchase_price].to_d if attrs[:purchase_price].present?
        attrs[:stock_level] = attrs[:stock_level].to_i if attrs[:stock_level].present?
        attrs[:reorder_level] = attrs[:reorder_level].to_i if attrs[:reorder_level].present?
        attrs[:order_quantity] = attrs[:order_quantity].to_i if attrs[:order_quantity].present?
        attrs[:unit_cost] = attrs[:unit_cost].to_d if attrs[:unit_cost].present?
        attrs[:items_per_unit] = attrs[:items_per_unit].to_i if attrs[:items_per_unit].present?

        # Associations
        supplier_name = row["Supplier"]&.strip
        attrs[:supplier_id] = supplier_map[supplier_name] if supplier_name.present?

        tax_value = row["Tax_Applied"]&.strip
        attrs[:tax_code_id] = tax_code_map[tax_value] if tax_value.present?

        # Preserve original date
        date_added = row["Date_Added"]&.strip
        if date_added.present? && was_new
          begin
            attrs[:created_at] = Time.parse(date_added)
          rescue ArgumentError
            # Ignore invalid dates
          end
        end

        product.assign_attributes(attrs)
        product.save!

        if was_new
          data_import.increment!(:created_count)
        else
          data_import.increment!(:updated_count)
        end

        # Assign category
        cat_name = row["Stock_Cat"]&.strip
        if cat_name.present? && category_map[cat_name]
          category = Category.find(category_map[cat_name])
          product.categories << category unless product.categories.include?(category)
        end
      end

      def build_supplier_map(rows)
        supplier_data = rows
          .select { |r| r["Supplier"].present? }
          .uniq { |r| r["Supplier"]&.strip }

        map = {}
        supplier_data.each do |row|
          name = row["Supplier"].strip
          phone = row["Supp_Phone"]&.strip

          supplier = Supplier.find_or_create_by!(name: name) do |s|
            s.phone = phone
          end
          supplier.update!(phone: phone) if phone.present? && supplier.phone.blank?
          map[name] = supplier.id
        end
        map
      end

      def build_category_map(rows)
        category_names = rows.map { |r| r["Stock_Cat"]&.strip }.compact_blank.uniq

        map = {}
        category_names.each do |name|
          category = Category.find_or_create_by!(name: name)
          map[name] = category.id
        end
        map
      end

      def build_tax_code_map
        map = {}
        # Map Tax_Applied values: "1" => books/exempt, "2" => standard/HST
        books_tax = TaxCode.find_by(code: "EXEMPT") || TaxCode.find_or_create_by!(code: "EXEMPT", name: "Exempt (Books)", rate: 0.0)
        standard_tax = TaxCode.find_by(code: "HST") || TaxCode.find_or_create_by!(code: "HST", name: "HST", rate: 13.0)

        map["1"] = books_tax.id
        map["2"] = standard_tax.id
        map
      end
  end
end
