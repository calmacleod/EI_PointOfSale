# frozen_string_literal: true

module ReportTemplates
  class OutOfStockProducts < ReportTemplate
    def self.key         = "out_of_stock_products"
    def self.title       = "Out of stock products"
    def self.description = "Shows products that are out of stock or below their reorder level, grouped by supplier."

    def self.parameters
      [
        {
          key: :scope,
          type: :select,
          label: "Include",
          required: true,
          options: [
            [ "Out of stock only (stock ≤ 0)", "out_of_stock" ],
            [ "Below reorder level", "below_reorder" ]
          ]
        }
      ]
    end

    def self.chart_type = "bar"

    def self.table_columns
      [
        { key: :code,             label: "Code" },
        { key: :name,             label: "Product" },
        { key: :supplier,         label: "Supplier" },
        { key: :stock_level,      label: "Stock" },
        { key: :reorder_level,    label: "Reorder level" },
        { key: :selling_price,    label: "Price" }
      ]
    end

    TABLE_LIMIT = 2_000

    def self.generate(params)
      products = fetch_products(params[:scope])
      total_count = products.size

      table_products = products.first(TABLE_LIMIT)
      table_data = table_products.map do |product|
        {
          code:          product.code,
          name:          product.name,
          supplier:      product.supplier&.name || "—",
          stock_level:   product.stock_level,
          reorder_level: product.reorder_level,
          selling_price: format_price(product.selling_price)
        }
      end

      by_supplier = products.group_by { |p| p.supplier&.name || "No supplier" }
                            .transform_values(&:count)
                            .sort_by { |_, count| -count }

      {
        chart: {
          labels: by_supplier.map(&:first),
          datasets: [
            {
              label: "Products",
              data: by_supplier.map(&:last),
              backgroundColor: "rgba(239, 68, 68, 0.6)",
              borderColor: "rgba(239, 68, 68, 1)",
              borderWidth: 1
            }
          ]
        },
        table: table_data,
        summary: build_summary(products, params[:scope], total_count)
      }
    end

    # ── Private helpers ────────────────────────────────────────────────

    def self.fetch_products(scope)
      base = Product.kept.includes(:supplier).order(:name)

      if scope == "below_reorder"
        base.where("stock_level <= reorder_level")
      else
        base.where(stock_level: ..0)
      end
    end

    def self.build_summary(products, scope, total_count)
      supplier_count = products.filter_map(&:supplier_id).uniq.count

      summary = {
        total_products: total_count,
        scope_label: scope == "below_reorder" ? "Below reorder level" : "Out of stock (≤ 0)",
        suppliers_affected: supplier_count,
        total_retail_value: format_price(products.sum(&:selling_price))
      }
      summary[:table_note] = "Showing first #{TABLE_LIMIT} of #{total_count} products" if total_count > TABLE_LIMIT
      summary
    end

    def self.format_price(amount)
      return "$0.00" if amount.nil? || amount.zero?

      "$#{'%.2f' % amount}"
    end

    private_class_method :fetch_products, :build_summary, :format_price

    register!
  end
end
