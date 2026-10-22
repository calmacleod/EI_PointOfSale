# frozen_string_literal: true

module ReportTemplates
  # A small, explicit reporting vocabulary. Column keys never become SQL or
  # arbitrary model attributes; expanding this list is a reviewed code change.
  class CustomExport < ReportTemplate
    DATASETS = {
      "sales" => {
        label: "Sales", description: "One row per completed sale in the date range. Amounts include original sales that were later refunded; use Refunds to examine returns.",
        columns: [
          [ :order_number, "Order #" ], [ :completed_at, "Sale date", :datetime ],
          [ :customer, "Customer" ], [ :member_number, "Member #" ], [ :status, "Status" ],
          [ :items, "Items", :integer ], [ :subtotal, "Subtotal", :currency ],
          [ :discount, "Discount", :currency ], [ :tax, "Tax", :currency ],
          [ :total, "Sale total (incl. tax)", :currency ], [ :payment_methods, "Payment methods" ]
        ]
      },
      "inventory" => {
        label: "Inventory", description: "One row per current product. Inventory is a snapshot at generation time; dates do not apply.",
        columns: [
          [ :code, "Code" ], [ :name, "Product" ], [ :supplier, "Supplier" ],
          [ :stock, "Stock", :integer ], [ :reorder_level, "Reorder level", :integer ],
          [ :unit_cost, "Unit cost", :currency ], [ :price, "Retail price", :currency ],
          [ :cost_value, "Cost value", :currency ], [ :retail_value, "Retail value", :currency ]
        ]
      },
      "customers" => {
        label: "Customers", description: "One row per current customer, including contact information. Dates do not apply.",
        columns: [
          [ :name, "Customer" ], [ :member_number, "Member #" ], [ :email, "Email" ],
          [ :phone, "Phone" ], [ :address, "Address" ], [ :city, "City" ],
          [ :province, "Province" ], [ :postal_code, "Postal code" ],
          [ :registered_on, "Registered on", :date ]
        ]
      },
      "refunds" => {
        label: "Refunds", description: "One row per refund issued in the date range, including returns for older sales. Refund totals include tax.",
        columns: [
          [ :refund_number, "Refund #" ], [ :refunded_at, "Refund date", :datetime ],
          [ :order_number, "Order #" ], [ :customer, "Customer" ],
          [ :total, "Refund total (incl. tax)", :currency ], [ :reason, "Reason" ]
        ]
      }
    }.freeze

    def self.key = "custom_export"
    def self.title = "Custom Excel export"
    def self.description = "Choose your data and columns, then use Excel to filter, total, or build a pivot table. Save a named result to reuse its settings."
    def self.table_columns = []

    def self.datasets
      DATASETS.map do |key, dataset|
        { key: key, label: dataset[:label], description: dataset[:description], columns: columns_for(key) }
      end
    end

    def self.columns_for(dataset)
      Array(DATASETS.dig(dataset, :columns)).map do |key, label, type|
        { key: key, label: label, type: type || :string }
      end
    end

    def self.parameters
      [
        { key: :dataset, label: "Data", type: :select, options: DATASETS.map { |key, data| [ data[:label], key ] } },
        { key: :start_date, label: "Start date", type: :date },
        { key: :end_date, label: "End date", type: :date },
        { key: :columns, label: "Columns", type: :columns, default: columns_for("sales").map { |column| column[:key].to_s } }
      ]
    end

    def self.normalize_parameters(values)
      result = super
      result["columns"] = columns_for(result["dataset"]).map { |column| column[:key].to_s } unless values.to_h.stringify_keys.key?("columns")
      result
    end

    def self.parameter_errors(values)
      values = values.to_h.stringify_keys
      errors = super
      selected = values["columns"]
      allowed = columns_for(values["dataset"]).map { |column| column[:key].to_s }
      unless selected.is_a?(Array) && selected.any? && selected.all? { |key| allowed.include?(key) } && selected.uniq == selected
        errors << "Choose at least one valid column for this data."
      end
      errors
    end

    def self.output_columns(params = {})
      selected = Array(params[:columns]).map(&:to_s)
      columns_for(params[:dataset]).select { |column| selected.include?(column[:key].to_s) }
    end

    def self.generate(params)
      errors = parameter_errors(params)
      raise ArgumentError, errors.join(" ") if errors.any?

      rows = case params[:dataset]
      when "sales" then sales_rows(params)
      when "inventory" then inventory_rows
      when "customers" then customer_rows
      when "refunds" then refund_rows(params)
      end
      keys = output_columns(params).map { |column| column[:key] }
      {
        table: rows.map { |row| row.slice(*keys) },
        summary: { records: rows.size, data: DATASETS.fetch(params[:dataset])[:label], notes: DATASETS.fetch(params[:dataset])[:description] }
      }
    end

    def self.sales_rows(params)
      start_date, end_date = report_date_range(params)
      Order.kept.where(status: %i[completed partially_refunded refunded], completed_at: start_date.beginning_of_day..end_date.end_of_day)
        .includes(:customer, :order_lines, :order_payments).order(:completed_at, :id).map do |order|
        {
          order_number: order.number, completed_at: order.completed_at.iso8601,
          customer: order.customer_name, member_number: order.customer&.member_number,
          status: order.status.humanize, items: order.order_lines.sum(&:quantity),
          subtotal: order.subtotal, discount: order.discount_total, tax: order.tax_total, total: order.total,
          payment_methods: order.order_payments.map { |payment| payment.payment_method.humanize }.uniq.join(", ")
        }
      end
    end

    def self.inventory_rows
      Product.kept.includes(:supplier).order(:name, :id).map do |product|
        cost = (product.unit_cost || product.purchase_price).to_d
        {
          code: product.code, name: product.name, supplier: product.supplier&.name,
          stock: product.stock_level, reorder_level: product.reorder_level,
          unit_cost: cost, price: product.selling_price,
          cost_value: cost * product.stock_level.to_i, retail_value: product.selling_price.to_d * product.stock_level.to_i
        }
      end
    end

    def self.customer_rows
      Customer.kept.order(:name, :id).map do |customer|
        {
          name: customer.name, member_number: customer.member_number, email: customer.email,
          phone: customer.phone, address: customer.address, city: customer.city,
          province: customer.province, postal_code: customer.postal_code, registered_on: customer.created_at.to_date.iso8601
        }
      end
    end

    def self.refund_rows(params)
      start_date, end_date = report_date_range(params)
      Refund.where(created_at: start_date.beginning_of_day..end_date.end_of_day).includes(order: :customer).order(:created_at, :id).map do |refund|
        {
          refund_number: refund.refund_number, refunded_at: refund.created_at.iso8601,
          order_number: refund.order.number, customer: refund.order.customer_name,
          total: refund.total, reason: refund.reason
        }
      end
    end

    private_class_method :sales_rows, :inventory_rows, :customer_rows, :refund_rows
    register!
  end
end
