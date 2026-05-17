# frozen_string_literal: true

module ReportTemplates
  class InventoryValuation < ReportTemplate
    TABLE_LIMIT = 2_000

    def self.key         = "inventory_valuation"
    def self.title       = "Inventory valuation"
    def self.description = "Values current product inventory at cost and retail, grouped by supplier with reorder-risk indicators."

    def self.parameters
      [
        {
          key: :scope,
          type: :select,
          label: "Inventory",
          required: false,
          options: [
            [ "All kept products", "" ],
            [ "In-stock products only", "in_stock" ],
            [ "Below reorder level", "below_reorder" ]
          ]
        }
      ]
    end

    def self.chart_type = "bar"

    def self.table_columns
      [
        { key: :code,          label: "Code" },
        { key: :name,          label: "Product" },
        { key: :supplier,      label: "Supplier" },
        { key: :stock_level,   label: "Stock" },
        { key: :unit_cost,     label: "Unit cost" },
        { key: :retail_price,  label: "Retail price" },
        { key: :cost_value,    label: "Cost value" },
        { key: :retail_value,  label: "Retail value" },
        { key: :margin_value,  label: "Potential margin" }
      ]
    end

    def self.generate(params)
      products = fetch_products(params[:scope].presence)
      rows = build_rows(products)
      by_supplier = build_supplier_breakdown(rows)

      {
        chart: {
          labels: by_supplier.map { |row| row[:supplier] },
          datasets: [
            {
              label: "Retail value",
              data: by_supplier.map { |row| row[:retail_value_amount] },
              backgroundColor: "rgba(59, 130, 246, 0.6)",
              borderColor: "rgba(59, 130, 246, 1)",
              borderWidth: 1
            },
            {
              label: "Cost value",
              data: by_supplier.map { |row| row[:cost_value_amount] },
              backgroundColor: "rgba(245, 158, 11, 0.55)",
              borderColor: "rgba(245, 158, 11, 1)",
              borderWidth: 1
            }
          ]
        },
        table: rows.first(TABLE_LIMIT).map { |row| row.except(:cost_value_amount, :retail_value_amount, :margin_value_amount) },
        summary: build_summary(rows)
      }
    end

    def self.fetch_products(scope)
      products = Product.kept.includes(:supplier).order(:name)

      case scope
      when "in_stock"
        products.where("stock_level > 0")
      when "below_reorder"
        products.where("stock_level <= reorder_level")
      else
        products
      end
    end
    private_class_method :fetch_products

    def self.build_rows(products)
      products.map do |product|
        stock_level = product.stock_level.to_i
        unit_cost = product.unit_cost || product.purchase_price || 0
        retail_price = product.selling_price || 0
        cost_value = unit_cost.to_d * stock_level
        retail_value = retail_price.to_d * stock_level
        margin_value = retail_value - cost_value

        {
          code: product.code,
          name: product.name,
          supplier: product.supplier&.name || "No supplier",
          stock_level: stock_level,
          reorder_level: product.reorder_level.to_i,
          unit_cost: format_currency(unit_cost),
          retail_price: format_currency(retail_price),
          cost_value_amount: cost_value,
          cost_value: format_currency(cost_value),
          retail_value_amount: retail_value,
          retail_value: format_currency(retail_value),
          margin_value_amount: margin_value,
          margin_value: format_currency(margin_value)
        }
      end.sort_by { |row| [ -row[:retail_value_amount], row[:name] ] }
    end
    private_class_method :build_rows

    def self.build_supplier_breakdown(rows)
      rows.group_by { |row| row[:supplier] }
          .map do |supplier, supplier_rows|
        {
          supplier: supplier,
          retail_value_amount: supplier_rows.sum { |row| row[:retail_value_amount] },
          cost_value_amount: supplier_rows.sum { |row| row[:cost_value_amount] }
        }
      end.sort_by { |row| -row[:retail_value_amount] }
    end
    private_class_method :build_supplier_breakdown

    def self.build_summary(rows)
      summary = {
        products: rows.size,
        units_on_hand: rows.sum { |row| row[:stock_level] },
        below_reorder: rows.count { |row| row[:stock_level] <= row[:reorder_level] },
        cost_value: format_currency(rows.sum { |row| row[:cost_value_amount] }),
        retail_value: format_currency(rows.sum { |row| row[:retail_value_amount] }),
        potential_margin: format_currency(rows.sum { |row| row[:margin_value_amount] })
      }
      summary[:table_note] = "Showing first #{TABLE_LIMIT} of #{rows.size} products" if rows.size > TABLE_LIMIT
      summary
    end
    private_class_method :build_summary

    register!
  end
end
