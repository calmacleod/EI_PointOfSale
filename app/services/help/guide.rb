# frozen_string_literal: true

module Help
  class Guide
    TOPICS = {
      "dashboard" => "getting-started", "register" => "register", "orders" => "orders-and-refunds",
      "order_lines" => "register", "order_payments" => "payments", "order_discounts" => "discounts",
      "order_line_discounts" => "discounts", "order_discount_overrides" => "discounts",
      "products" => "products", "restocks" => "inventory", "services" => "services",
      "customers" => "customers", "inventory" => "inventory", "cash_drawer" => "cash-drawer",
      "reports" => "reports", "store_tasks" => "store-tasks", "notifications" => "notifications",
      "offline" => "offline-lookup", "profiles" => "accounts-and-access", "search" => "search-and-filters",
      "gift_certificates" => "gift-certificates", "admin_area/gift_certificates" => "gift-certificates",
      "admin_area/settings" => "administration", "admin_area/store" => "store-and-receipts",
      "admin_area/receipt_templates" => "store-and-receipts", "admin_area/users" => "accounts-and-access",
      "admin_area/tax_codes" => "tax-codes", "admin_area/suppliers" => "products",
      "admin_area/discounts" => "discounts", "admin_area/imports" => "stock-imports",
      "admin_area/shopify" => "shopify", "admin_area/backups" => "backups-and-exports",
      "admin_area/data_exports" => "backups-and-exports", "admin_area/audits" => "administration",
      "admin_area/recurring_tasks" => "administration"
    }.freeze

    FEATURE_PATHS = {
      "dashboard" => :root_path, "register" => :register_path, "orders" => :orders_path,
      "products" => :products_path, "services" => :services_path, "customers" => :customers_path,
      "inventory" => :inventory_path, "cash_drawer" => :cash_drawer_path, "reports" => :reports_path,
      "store_tasks" => :store_tasks_path, "notifications" => :notifications_path, "offline" => :offline_path,
      "profile" => :edit_profile_path, "admin_settings" => :admin_settings_path,
      "admin_store" => :admin_store_path, "admin_tax_codes" => :admin_tax_codes_path,
      "admin_imports" => :new_admin_import_path, "admin_shopify" => :admin_shopify_path,
      "admin_backups" => :admin_backups_path
    }.freeze

    def self.all
      # Content changes are visible immediately while authoring in development.
      return load_guides if Rails.env.development?

      @guides ||= load_guides
    end

    def self.visible_to(user)
      all.select { |guide| guide["audience"] != "admin" || user.is_a?(Admin) }
    end

    def self.topic_for(controller_path)
      TOPICS.fetch(controller_path, "getting-started")
    end

    def self.load_guides
      Dir[Rails.root.join("docs/help/*.yml")].map do |path|
        YAML.safe_load_file(path).merge("slug" => File.basename(path, ".yml"))
      end.sort_by { |guide| guide.fetch("position") }.freeze
    end
    private_class_method :load_guides
  end
end
