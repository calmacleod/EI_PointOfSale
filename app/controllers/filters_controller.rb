# frozen_string_literal: true

class FiltersController < ApplicationController
  # Renders an individual filter chip for the filter bar.
  # Expects params:
  #   resource: the resource name (e.g., "products", "services")
  #   key: the filter key (e.g., "supplier_id", "sync_to_shopify")
  def chip
    resource = params[:resource].to_s
    key = params[:key].to_sym

    # Find the filter configuration
    config = find_filter_config(resource)
    filter_def = config&.filters&.find { |f| f.key == key }

    if filter_def.nil?
      head :not_found
      return
    end

    form_id = params[:form_id].presence || "#{resource}_filter_form"

    respond_to do |format|
      format.html {
        render partial: "filters/chip",
               locals: { filter: filter_def, resource: resource, form_id: form_id }
      }
    end
  end

  private

    def find_filter_config(resource)
      case resource
      when "products"
        build_product_config
      when "services"
        build_service_config
      when "customers"
        build_customer_config
      when "orders"
        build_order_config
      when "users"
        build_user_config
      when "tax_codes"
        build_tax_code_config
      when "suppliers"
        build_supplier_config
      when "reports"
        build_report_config
      when "store_tasks"
        build_store_task_config
      else
        nil
      end
    end

    def build_product_config
      FilterConfig.new(:products, products_path) do |f|
        f.association  :supplier_id,      label: "Supplier",      collection: -> { Supplier.kept.order(:name) }
        f.association  :tax_code_id,      label: "Tax Code",      collection: -> { TaxCode.kept.order(:code) }, display: :code
        f.association  :product_group_id, label: "Product Group",  collection: -> { ProductGroup.order(:name) }
        f.multi_select :category_ids,     label: "Categories",
                       collection: -> { Category.kept.order(:name) }
        f.boolean      :sync_to_shopify,  label: "Shopify Sync"
        f.number_range :selling_price,    label: "Price"
        f.number_range :stock_level,      label: "Stock"
        f.date_range   :created_at,       label: "Created"
        f.date_range   :updated_at,       label: "Updated"
      end
    end

    def build_service_config
      FilterConfig.new(:services, services_path) do |f|
        f.association  :tax_code_id,  label: "Tax Code",   collection: -> { TaxCode.kept.order(:code) }, display: :code
        f.multi_select :category_ids, label: "Categories",
                       collection: -> { Category.kept.order(:name) }
        f.number_range :price,        label: "Price"
        f.date_range   :created_at,  label: "Created"
        f.date_range   :updated_at,  label: "Updated"
      end
    end

    def build_customer_config
      FilterConfig.new(:customers, customers_path) do |f|
        f.boolean :tax_exempt, label: "Tax Exempt"
        f.date_range :created_at, label: "Created"
      end
    end

    def build_order_config
      FilterConfig.new(:orders, orders_path) do |f|
        f.date_range :created_at, label: "Created"
      end
    end

    def build_user_config
      FilterConfig.new(:users, admin_users_path) do |f|
        # No specific filters defined yet
      end
    end

    def build_tax_code_config
      FilterConfig.new(:tax_codes, admin_tax_codes_path) do |f|
        # No specific filters defined yet
      end
    end

    def build_supplier_config
      FilterConfig.new(:suppliers, admin_suppliers_path) do |f|
        # No specific filters defined yet
      end
    end

    def build_report_config
      FilterConfig.new(:reports, reports_path) do |f|
        f.date_range :created_at, label: "Created"
      end
    end

    def build_store_task_config
      FilterConfig.new(:store_tasks, store_tasks_path) do |f|
        f.date_range :created_at, label: "Created"
      end
    end
end
