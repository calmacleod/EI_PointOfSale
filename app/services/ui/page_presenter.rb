# frozen_string_literal: true

module Ui
  class PagePresenter
    RESOURCE_CONFIGS = {
      "products" => {
        title: "Products", singular: "Product", collection: :products, record: :product,
        description: "Manage sellable inventory, pricing, suppliers, and Shopify settings.",
        fields: [
          [ :code, "SKU / Code", :text, true ], [ :name, "Name", :text, true ],
          [ :selling_price, "Selling price", :number, true, { step: "0.01", min: 0 } ],
          [ :purchase_price, "Purchase price", :number, false, { step: "0.01", min: 0 } ],
          [ :stock_level, "Stock level", :number, false, { step: 1, min: 0 } ],
          [ :reorder_level, "Reorder level", :number, false, { step: 1, min: 0 } ],
          [ :tax_code_id, "Tax code", :select, false, { source: :tax_codes } ],
          [ :supplier_id, "Supplier", :select, false, { source: :suppliers } ],
          [ :product_group_id, "Product group", :select, false, { source: :product_groups } ],
          [ :supplier_reference, "Supplier reference", :text, false ],
          [ :unit_cost, "Unit cost", :number, false, { step: "0.01", min: 0 } ],
          [ :items_per_unit, "Items per unit", :number, false, { step: 1, min: 1 } ],
          [ :order_quantity, "Order quantity", :number, false, { step: 1, min: 0 } ],
          [ :product_url, "Product URL", :url, false ], [ :notes, "Notes", :textarea, false ],
          [ :sync_to_shopify, "Sync to Shopify", :checkbox, false ],
          [ :images, "Images", :file, false, { multiple: true, accept: "image/*" } ]
        ],
        show: %i[code name selling_price purchase_price stock_level reorder_level supplier tax_code product_group categories supplier_reference product_url notes sync_to_shopify created_at updated_at]
      },
      "services" => {
        title: "Services", singular: "Service", collection: :services, record: :service,
        description: "Manage services, pricing, tax treatment, and categories.",
        fields: [
          [ :name, "Name", :text, true ], [ :code, "Code", :text, false ],
          [ :description, "Description", :textarea, false ],
          [ :price, "Price", :number, true, { step: "0.01", min: 0 } ],
          [ :tax_code_id, "Tax code", :select, false, { source: :tax_codes } ]
        ],
        show: %i[name code description price tax_code categories sales_count created_at updated_at]
      },
      "customers" => {
        title: "Customers", singular: "Customer", collection: :customers, record: :customer,
        description: "Manage customer contact, membership, tax, and discount details.",
        fields: [
          [ :name, "Name", :text, true ], [ :member_number, "Member number", :text, false ],
          [ :email, "Email", :email, false ], [ :phone, "Phone", :tel, false ],
          [ :date_of_birth, "Date of birth", :date, false ], [ :active, "Active", :checkbox, false ],
          [ :account_status, "Account status", :number, false, { min: 0 } ],
          [ :discount_id, "Discount", :select, false, { source: :discounts } ],
          [ :address_line1, "Address line 1", :text, false ], [ :address_line2, "Address line 2", :text, false ],
          [ :city, "City", :text, false ], [ :province, "Province", :text, false ],
          [ :postal_code, "Postal code", :text, false ], [ :country, "Country", :text, false ],
          [ :status_card_number, "Status card number", :text, false ],
          [ :alert, "Register alert", :textarea, false ], [ :notes, "Notes", :textarea, false ]
        ],
        show: %i[name member_number account_status active email phone date_of_birth address tax_code discount status_card_number alert notes joining_date created_at updated_at]
      },
      "store_tasks" => {
        title: "Store Tasks", singular: "Task", collection: :store_tasks, record: :store_task,
        description: "Track work that needs to be completed around the store.",
        fields: [
          [ :title, "Title", :text, true ], [ :body, "Description", :textarea, false ],
          [ :status, "Status", :select, true, { source: :store_task_statuses } ],
          [ :assigned_to_id, "Assign to", :select, false, { source: :users } ],
          [ :due_date, "Due date", :date, false ]
        ],
        show: %i[title body status assigned_to due_date created_at updated_at]
      },
      "admin_area/users" => {
        title: "Users", singular: "User", collection: :users, record: :user, admin: true,
        description: "Manage staff accounts, roles, and access.",
        fields: [
          [ :name, "Name", :text, true ], [ :email_address, "Email", :email, true ],
          [ :phone, "Phone", :tel, false ], [ :type, "Role", :select, true, { source: :user_types } ],
          [ :active, "Active", :checkbox, false ], [ :notes, "Notes", :textarea, false ],
          [ :password, "Password", :password, false ], [ :password_confirmation, "Confirm password", :password, false ]
        ],
        show: %i[name email_address phone type active notes created_at updated_at]
      },
      "admin_area/tax_codes" => {
        title: "Tax Codes", singular: "Tax code", collection: :tax_codes, record: :tax_code, admin: true,
        description: "Configure tax rates and exemption categories.",
        fields: [
          [ :code, "Code", :text, true ], [ :name, "Name", :text, true ],
          [ :rate, "Rate", :number, true, { step: "0.0001", min: 0 } ],
          [ :province_code, "Province code", :text, false ], [ :exemption_type, "Exemption type", :text, false ],
          [ :notes, "Notes", :textarea, false ]
        ],
        show: %i[code name rate province_code exemption_type notes created_at updated_at]
      },
      "admin_area/suppliers" => {
        title: "Suppliers", singular: "Supplier", collection: :suppliers, record: :supplier, admin: true,
        description: "Manage product suppliers and contact details.",
        fields: [ [ :name, "Name", :text, true ], [ :phone, "Phone", :tel, false ] ],
        show: %i[name phone created_at updated_at]
      },
      "admin_area/discounts" => {
        title: "Discounts", singular: "Discount", collection: :discounts, record: :discount, admin: true,
        description: "Configure order and item discounts.",
        fields: [
          [ :name, "Name", :text, true ], [ :description, "Description", :textarea, false ],
          [ :discount_type, "Type", :select, true, { source: :discount_types } ],
          [ :value, "Value", :number, true, { step: "0.01", min: 0 } ],
          [ :active, "Active", :checkbox, false ], [ :applies_to_all, "Applies to all", :checkbox, false ],
          [ :starts_at, "Starts at", :datetime_local, false ], [ :ends_at, "Ends at", :datetime_local, false ]
        ],
        show: %i[name description discount_type value active applies_to_all starts_at ends_at created_at updated_at]
      },
      "admin_area/receipt_templates" => {
        title: "Receipt Templates", singular: "Receipt template", collection: :receipt_templates, record: :receipt_template, admin: true,
        description: "Control printed receipt content and formatting.",
        fields: [
          [ :name, "Name", :text, true ], [ :paper_width_mm, "Paper width", :select, true, { source: :paper_widths } ],
          [ :header_text, "Header text", :textarea, false ],
          [ :footer_text, "Footer text", :textarea, false ], [ :show_logo, "Show logo", :checkbox, false ],
          [ :trim_logo, "Trim logo whitespace", :checkbox, false ], [ :show_store_name, "Show store name", :checkbox, false ],
          [ :show_store_address, "Show store address", :checkbox, false ], [ :show_store_phone, "Show store phone", :checkbox, false ],
          [ :show_store_email, "Show store email", :checkbox, false ], [ :show_cashier_name, "Show cashier", :checkbox, false ],
          [ :show_date_time, "Show date and time", :checkbox, false ]
        ],
        show: %i[name active paper_width_mm chars_per_line header_text footer_text show_logo show_store_name show_store_address show_store_phone show_store_email show_cashier_name show_date_time created_at updated_at]
      }
    }.freeze

    def initialize(controller, action_name: nil, controller_path: nil)
      @controller = controller
      @assigns = controller.view_assigns.symbolize_keys
      @params = controller.params
      @action_override = action_name&.to_s
      @path_override = controller_path&.to_s
    end

    def call
      return auth_props if controller_path == "sessions" || controller_path == "passwords"
      return dashboard_props if controller_path == "dashboard"
      return register_props if controller_path == "register"
      return offline_props if controller_path == "offline"
      return reports_props if controller_path == "reports"
      return orders_props if controller_path == "orders"
      return inventory_props if controller_path == "inventory"
      return cash_drawer_props if controller_path == "cash_drawer"
      return profile_props if controller_path == "profiles"
      return admin_store_props if controller_path == "admin_area/store"
      return admin_settings_props if controller_path == "admin_area/settings"
      return notifications_props if controller_path == "notifications"
      return gift_certificate_props if controller_path == "admin_area/gift_certificates"
      return audit_props if controller_path == "admin_area/audits"
      return imports_props if controller_path == "admin_area/imports"
      return shopify_props if controller_path == "admin_area/shopify"
      return backups_props if controller_path == "admin_area/backups"
      return recurring_tasks_props if controller_path == "admin_area/recurring_tasks"
      return data_export_props if controller_path == "admin_area/data_exports"
      return restocks_props if controller_path == "restocks"
      return receipt_template_props if controller_path == "admin_area/receipt_templates" && action_name == "show"
      return operational_props if operational_controller?

      config = RESOURCE_CONFIGS[controller_path]
      return resource_props(config) if config

      generic_props
    end

    private

      attr_reader :controller, :assigns, :params

      def controller_path
        @path_override || controller.controller_path
      end

      def action_name
        @action_override || controller.action_name
      end

      def h
        controller.helpers
      end

      def resource_props(config)
        case action_name
        when "index" then resource_index_props(config)
        when "new", "edit" then resource_form_props(config)
        when "show" then resource_show_props(config)
        else generic_props
        end
      end

      def resource_index_props(config, extra: {})
        records = Array(assigns[config[:collection]])
        filter_config = assigns[:filter_config]
        columns = if filter_config
          JSON.parse(filter_config.columns_json, symbolize_names: true).select { |column| column[:default] }
        else
          fallback_columns(records.first)
        end

        {
          view: "resource_index",
          title: config[:title],
          description: config[:description],
          resource_key: filter_config&.resource_name || config[:collection].to_s,
          columns: columns,
          rows: records.map { |record| index_row(record, columns, config) },
          filters: filter_config ? JSON.parse(filter_config.filters_json, symbolize_names: true) : [],
          query: safe_query_params,
          pagination: pagination_props(assigns[:pagy]),
          actions: {
            index: collection_path(config),
            new: new_resource_path(config)
          },
          can_create: can_create?(config),
          empty_message: "No #{config[:title].downcase} match the current filters."
        }.merge(extra)
      end

      def resource_form_props(config, record: nil, action: nil, root: nil, cancel: nil)
        record ||= assigns[config[:record]]
        fields = config[:fields].map { |field| form_field_props(field, record) }
        persisted = record&.persisted?

        {
          view: "resource_form",
          title: persisted ? "Edit #{record_label(record, config)}" : "New #{config[:singular].to_s.titleize}",
          description: config[:description],
          form: {
            root: root || config[:record].to_s,
            method: persisted ? "patch" : "post",
            action: action || (persisted ? record_path(record, config) : collection_path(config)),
            cancel: cancel || (persisted ? record_path(record, config) : collection_path(config)),
            submit_label: persisted ? "Save changes" : "Create #{config[:singular].downcase}",
            delete_path: persisted ? record_path(record, config) : nil,
            fields: fields,
            errors: record&.errors&.full_messages || []
          }
        }
      end

      def resource_show_props(config, record: nil)
        record ||= assigns[config[:record]]
        {
          view: "resource_show",
          title: record_label(record, config),
          description: config[:description],
          details: Array(config[:show]).map { |key| { label: key.to_s.humanize, value: display_value(record, key) } },
          actions: {
            index: collection_path(config),
            edit: edit_resource_path(record, config),
            delete: record_path(record, config)
          }
        }
      end

      def auth_props
        if controller_path == "sessions"
          {
            view: "auth",
            title: "Sign in",
            description: "Use your staff account to open the point of sale.",
            form: {
              action: controller.send(:session_path), method: "post", root: nil,
              submit_label: "Sign in",
              fields: [
                { key: "email_address", label: "Email address", type: "email", value: params[:email_address].to_s, required: true, autocomplete: "username" },
                { key: "password", label: "Password", type: "password", value: "", required: true, autocomplete: "current-password" }
              ]
            },
            secondary: { label: "Forgot your password?", path: controller.send(:new_password_path) }
          }
        elsif action_name == "new"
          {
            view: "auth", title: "Reset password", description: "We will send reset instructions if the account exists.",
            form: {
              action: controller.send(:passwords_path), method: "post", root: nil, submit_label: "Email reset instructions",
              fields: [ { key: "email_address", label: "Email address", type: "email", value: "", required: true, autocomplete: "username" } ]
            },
            secondary: { label: "Back to sign in", path: controller.send(:new_session_path) }
          }
        else
          {
            view: "auth", title: "Choose a new password", description: "Enter and confirm the new password for this account.",
            form: {
              action: controller.send(:password_path, params[:token]), method: "put", root: nil, submit_label: "Save password",
              fields: [
                { key: "password", label: "New password", type: "password", value: "", required: true, autocomplete: "new-password" },
                { key: "password_confirmation", label: "Confirm password", type: "password", value: "", required: true, autocomplete: "new-password" }
              ]
            }
          }
        end
      end

      def offline_props
        {
          view: "offline",
          title: "Offline lookup",
          allow_fake_offline: Rails.env.development?,
          home_path: controller.send(:root_path),
          sync_paths: {
            products: controller.send(:api_v1_products_sync_path),
            services: controller.send(:api_v1_services_sync_path),
            customers: controller.send(:api_v1_customers_sync_path),
            tax_codes: controller.send(:api_v1_tax_codes_sync_path)
          }
        }
      end

      def dashboard_props
        metrics = Array(assigns[:visible_metrics]).map do |metric|
          value = metric[:format].to_s == "currency" ? h.number_to_currency(metric[:value].to_d) : h.number_with_delimiter(metric[:value].to_i)
          { key: metric[:key], label: metric[:label], description: metric[:description], value: value, path: safe_public_path(metric[:link_path]) }
        end

        {
          view: "dashboard",
          title: "Dashboard",
          description: controller.send(:current_user) ? "Welcome back, #{controller.send(:current_user).email_address}." : "Overview and shortcuts for your point of sale.",
          metrics: metrics,
          metrics_last_updated: format_time(assigns[:metrics_last_updated]),
          drawer: drawer_props(CashDrawerSession.current),
          recent_orders: Array(assigns[:recent_orders]).map { |order| order_summary(order) },
          tasks: Array(assigns[:my_tasks]).map { |task| task_summary(task) },
          actions: {
            register: controller.send(:register_path), orders: controller.send(:orders_path),
            tasks: controller.send(:store_tasks_path), cash_drawer: controller.send(:cash_drawer_path),
            open_drawer: controller.send(:open_cash_drawer_path), close_drawer: controller.send(:close_cash_drawer_path)
          },
          section_titles: [ "Recent orders", "Your tasks" ]
        }
      end

      def register_props
        order = assigns[:order]
        {
          view: "register",
          title: "Register",
          order: order_props(order),
          active_orders: Array(assigns[:active_orders]).map { |active_order| order_summary(active_order) },
          held_count: assigns[:held_count].to_i,
          actions: {
            register: controller.send(:register_path),
            new_order: controller.send(:new_order_register_path),
            held: controller.send(:held_orders_path),
            quick_lookup: controller.send(:quick_lookup_orders_path),
            hold: controller.send(:hold_order_path, order),
            resume: controller.send(:resume_order_path, order),
            complete: controller.send(:complete_order_path, order),
            cancel: controller.send(:cancel_order_path, order),
            update: controller.send(:order_path, order),
            assign_customer: controller.send(:assign_customer_order_path, order),
            remove_customer: controller.send(:remove_customer_order_path, order),
            customer_search: controller.send(:search_customers_path),
            payment: controller.send(:order_order_payments_path, order),
            discount: controller.send(:order_order_discounts_path, order),
            gift_certificate: controller.send(:order_gift_certificates_path, order)
          }
        }
      end

      def reports_props
        config = {
          title: "Reports", singular: "Report", collection: :reports, record: :report,
          description: "Generate, review, and export business reports."
        }
        case action_name
        when "index"
          templates = Array(assigns[:templates]).map do |template|
            { key: template.key, title: template.title, description: template.description, path: controller.send(:new_report_path, template: template.key) }
          end
          resource_index_props(config, extra: { templates: templates })
        when "new"
          template = assigns[:template]
          {
            view: "report_form", title: template.title, description: template.description,
            form: {
              action: controller.send(:reports_path), report_type: template.key,
              parameters: template.parameters.map { |parameter| parameter.transform_values { |value| value.respond_to?(:to_json) ? value.as_json : value } },
              errors: Array(assigns[:report]&.errors&.full_messages)
            }
          }
        when "show"
          report = assigns[:report]
          {
            view: "report_show", title: report.title, description: report.template&.description,
            report: {
              id: report.id, status: report.status, report_type: report.report_type,
              parameters: report.parameters, result_data: report.result_data, error_message: report.error_message,
              generated_by: human_label(report.generated_by), created_at: format_time(report.created_at), completed_at: format_time(report.completed_at),
              table_columns: Array(report.template&.table_columns).map { |column| { key: column[:key].to_s, label: column[:label].to_s } },
              chart_type: report.template&.chart_type
            },
            actions: {
              index: controller.send(:reports_path), pdf: controller.send(:export_pdf_report_path, report),
              excel: controller.send(:export_excel_report_path, report), delete: controller.send(:report_path, report)
            }
          }
        else generic_props
        end
      end

      def orders_props
        case action_name
        when "index", "held"
          records = action_name == "held" ? assigns[:held_orders] : assigns[:orders]
          config = { title: action_name == "held" ? "Held Orders" : "Orders", singular: "Order", collection: action_name == "held" ? :held_orders : :orders, record: :order, description: "Review sales, payments, customers, and order state." }
          assigns[config[:collection]] = records
          resource_index_props(config)
        when "show" then order_show_props(assigns[:order])
        when "receipt" then receipt_props(assigns[:order])
        when "refund_form" then refund_props(assigns[:order])
        else generic_props
        end
      end

      def order_show_props(order)
        {
          view: "order_show", title: "Order #{order.number}", description: "#{order.status.humanize} order details.",
          order: order_props(order),
          events: order.order_events.order(created_at: :desc).limit(30).map { |event| { type: event.event_type.humanize, actor: human_label(event.actor), at: format_time(event.created_at), data: event.data } },
          actions: {
            index: controller.send(:orders_path), receipt: controller.send(:receipt_order_path, order),
            refund: controller.send(:refund_form_order_path, order), register: controller.send(:register_path, order_id: order.id)
          }
        }
      end

      def receipt_props(order)
        {
          view: "receipt", title: "Receipt #{order.number}",
          store: safe_attributes(assigns[:store], %i[name phone email address_line1 address_line2 city province postal_code country]),
          order: order_props(order), receipt_lines: Array(assigns[:receipt_lines]),
          actions: { order: controller.send(:order_path, order), index: controller.send(:orders_path) }
        }
      end

      def refund_props(order)
        {
          view: "refund", title: "Refund #{order.number}", description: "Choose returned quantities and whether stock should be restored.",
          order: order_props(order), action: controller.send(:process_refund_order_path, order),
          errors: Array(assigns[:refund_errors] || assigns[:errors])
        }
      end

      def inventory_props
        {
          view: "inventory", title: "Inventory Restock", description: "Find products, enter quantities, and commit the stock movement together.",
          actions: { lookup: controller.send(:lookup_inventory_path), restock: controller.send(:restock_inventory_path), import: controller.send(:import_inventory_path) }
        }
      end

      def cash_drawer_props
        case action_name
        when "show"
          {
            view: "cash_drawer", title: "Cash Drawer", description: "Open, close, and reconcile the physical register.",
            session: drawer_props(assigns[:session]), pending_reconciliation: drawer_props(assigns[:pending_reconciliation]),
            recent_sessions: Array(assigns[:recent_sessions]).map { |session| drawer_props(session) },
            actions: { open: controller.send(:open_cash_drawer_path), close: controller.send(:close_cash_drawer_path), reconcile: controller.send(:reconcile_cash_drawer_path), history: controller.send(:history_cash_drawer_path) }
          }
        when "new_open", "new_close"
          drawer_count_props(action_name == "new_open" ? "Open Register" : "Close Register", action_name == "new_open" ? controller.send(:open_cash_drawer_path) : controller.send(:close_cash_drawer_path), assigns[:session])
        when "new_reconcile"
          reconciliation = assigns[:reconciliation]
          {
            view: "reconcile", title: "Reconcile Terminal", description: "Compare terminal totals with recorded electronic payments.",
            reconciliation: {
              debit_total: reconciliation.debit_total, credit_total: reconciliation.credit_total,
              expected_debit_total: reconciliation.expected_debit_total, expected_credit_total: reconciliation.expected_credit_total,
              errors: reconciliation.errors.full_messages
            },
            action: controller.send(:reconcile_cash_drawer_path)
          }
        when "history"
          config = { title: "Cash Drawer History", singular: "Session", collection: :sessions, record: :session, description: "Review completed cash drawer sessions and discrepancies." }
          resource_index_props(config)
        when "session_detail"
          session = assigns[:session]
          {
            view: "resource_show", title: "Cash Drawer Session ##{session.id}", description: "Opening, closing, and terminal reconciliation details.",
            details: drawer_props(session).map { |key, value| { label: key.to_s.humanize, value: value } },
            actions: { index: controller.send(:history_cash_drawer_path), edit: nil, delete: nil }
          }
        else generic_props
        end
      end

      def drawer_count_props(title, action, session)
        denominations = CashDrawerSession::DENOMINATIONS.map do |key, value|
          label = CashDrawerSession::COIN_ROLLS.dig(key, :label) || key
          { key: key, label: label, value: value.to_f }
        end
        { view: "drawer_count", title: title, description: "Count each denomination before continuing.", action: action, denominations: denominations, errors: Array(session&.errors&.full_messages) }
      end

      def profile_props
        config = {
          title: "Profile", singular: "Profile", record: :user, description: "Update your account and display preferences.",
          fields: [
            [ :name, "Name", :text, true ], [ :email_address, "Email", :email, true ], [ :phone, "Phone", :tel, false ],
            [ :notes, "Notes", :textarea, false ], [ :theme, "Theme", :select, true, { source: :themes } ],
            [ :font_size, "Font size", :select, true, { source: :font_sizes } ],
            [ :password, "New password", :password, false ], [ :password_confirmation, "Confirm password", :password, false ]
          ]
        }
        resource_form_props(config, record: assigns[:user], action: controller.send(:profile_path), root: "user", cancel: controller.send(:root_path))
      end

      def admin_store_props
        store = assigns[:store]
        config = {
          title: "Store Settings", singular: "Store", record: :store, description: "Manage store identity, contact details, and branding.",
          fields: [
            [ :name, "Store name", :text, true ], [ :phone, "Phone", :tel, false ], [ :email, "Email", :email, false ],
            [ :accent_color, "Accent color", :select, false, { source: :accent_colors } ], [ :address_line1, "Address line 1", :text, false ],
            [ :address_line2, "Address line 2", :text, false ], [ :city, "City", :text, false ],
            [ :province, "Province", :text, false ], [ :postal_code, "Postal code", :text, false ], [ :country, "Country", :text, false ],
            [ :logo, "Store logo", :file, false, { accept: "image/*" } ]
          ]
        }
        resource_form_props(config, record: store, action: controller.send(:admin_store_path), root: "store", cancel: controller.send(:admin_settings_path)).merge(title: "Store Settings")
      end

      def admin_settings_props
        cards = [
          [ "Store", "Business identity and branding", :admin_store_path ], [ "Users", "Staff accounts and permissions", :admin_users_path ],
          [ "Tax codes", "Rates and exemptions", :admin_tax_codes_path ], [ "Suppliers", "Product suppliers", :admin_suppliers_path ],
          [ "Discounts", "Automatic and manual discounts", :admin_discounts_path ], [ "Gift certificates", "Issued balances and redemptions", :admin_gift_certificates_path ],
          [ "Receipt templates", "Printed receipt formatting", :admin_receipt_templates_path ], [ "Stock imports", "Bulk stock CSV imports", :new_admin_import_path ],
          [ "Shopify", "Product and inventory synchronization", :admin_shopify_path ], [ "Backups", "Database and object backups", :admin_backups_path ],
          [ "Audit log", "Administrative change history", :admin_audits_path ], [ "Recurring tasks", "Scheduled background work", :admin_recurring_tasks_path ],
          [ "Data export", "Download the application dataset", :admin_data_export_path ]
        ]
        { view: "cards", title: "Admin Settings", description: "Configuration, integrations, security, and operations.", cards: cards.map { |title, description, path| { title: title, description: description, path: controller.send(path) } } }
      end

      def notifications_props
        notifications = Array(assigns[:notifications]).map do |notification|
          { id: notification.id, title: notification.title, body: notification.body, category: notification.category, read: notification.read_at.present?, at: format_time(notification.created_at), url: notification.url, path: controller.send(:notification_path, notification) }
        end
        { view: "notifications", title: "Notifications", notifications: notifications, unread_count: assigns[:unread_count].to_i, actions: { mark_all: controller.send(:mark_all_read_notifications_path), clear_all: controller.send(:clear_all_notifications_path) } }
      end

      def gift_certificate_props
        config = {
          title: "Gift Certificates", singular: "Gift Certificate", collection: :gift_certificates,
          record: :gift_certificate, admin: true, description: "Review issued balances and redemptions.",
          show: %i[code status initial_amount remaining_balance customer sold_on_order issued_by activated_at voided_at created_at updated_at]
        }
        return resource_index_props(config) if action_name == "index"

        certificate = assigns[:gift_certificate]
        {
          view: "gift_certificate_show", title: certificate.code, description: "Gift certificate details and redemption history.",
          certificate: {
            code: certificate.code, status: certificate.status,
            initial_amount: h.number_to_currency(certificate.initial_amount),
            remaining_balance: h.number_to_currency(certificate.remaining_balance),
            customer: human_label(certificate.customer), sold_on_order: human_label(certificate.sold_on_order),
            issued_by: human_label(certificate.issued_by), activated_at: format_time(certificate.activated_at),
            voided_at: format_time(certificate.voided_at), created_at: format_time(certificate.created_at),
            updated_at: format_time(certificate.updated_at)
          },
          store: safe_attributes(assigns[:store], %i[name phone email address_line1 address_line2 city province postal_code country]),
          redemptions: Array(assigns[:redemptions]).map do |payment|
            {
              order: payment.order.number, order_path: controller.send(:order_path, payment.order),
              amount: h.number_to_currency(payment.amount), received_by: human_label(payment.received_by),
              created_at: format_time(payment.created_at)
            }
          end,
          actions: { index: controller.send(:admin_gift_certificates_path) }
        }
      end

      def audit_props
        if action_name == "index"
          config = {
            title: "Audit Trail", singular: "Audit", collection: :audits, record: :audit,
            description: "Review recorded changes and their actors.", admin: true
          }
          props = resource_index_props(config)
          props[:rows].each_with_index do |row, index|
            audit = Array(assigns[:audits])[index]
            row[:show_path] = controller.send(:admin_audit_path, audit)
            row[:edit_path] = nil
          end
          props[:actions][:new] = nil
          props[:can_create] = false
          return props
        end

        audit = assigns[:audit]
        {
          view: "resource_show", title: "Audit ##{audit.id}", description: "Recorded change details.",
          details: [
            { label: "Action", value: audit.action }, { label: "Model", value: audit.auditable_type },
            { label: "Record", value: "#{audit.auditable_type} ##{audit.auditable_id}" },
            { label: "User", value: human_label(audit.user) }, { label: "When", value: format_time(audit.created_at) },
            { label: "Changes", value: audit.audited_changes }
          ],
          actions: { index: controller.send(:admin_audits_path), edit: nil, delete: nil }
        }
      end

      def imports_props
        data_import = assigns[:data_import]
        preview = assigns[:preview]
        details = []
        if data_import
          details.concat([
            { label: "File name", value: data_import.file_name.presence || "—" },
            { label: "Status", value: data_import.status.to_s.humanize },
            { label: "Progress", value: "#{data_import.progress_percentage}%" },
            { label: "Processed rows", value: "#{data_import.processed_rows.to_i} / #{data_import.total_rows.to_i}" },
            { label: "Created", value: data_import.created_count.to_i },
            { label: "Updated", value: data_import.updated_count.to_i },
            { label: "Errors", value: data_import.error_count.to_i },
            { label: "Imported by", value: human_label(data_import.imported_by) }
          ])
        end
        if preview
          details.concat([
            { label: "Total rows", value: preview[:total_rows] },
            { label: "Categories", value: Array(preview[:categories]).join(", ") },
            { label: "Suppliers", value: Array(preview[:suppliers]).join(", ") },
            { label: "Duplicate codes", value: preview[:duplicate_codes] },
            { label: "Blank codes", value: preview[:blank_codes] },
            { label: "Sample rows", value: preview[:sample_rows] }
          ])
        end

        actions = [ { label: "Upload CSV", path: controller.send(:admin_imports_path), method: "post", upload: true } ]
        if action_name == "preview" && data_import&.persisted?
          actions << { label: "Run import", path: controller.send(:execute_admin_import_path, data_import), method: "patch" }
        end
        {
          view: "operations", title: action_name == "preview" ? "Import Preview" : action_name == "show" ? "Import Status" : "Data Import",
          description: "Preview and import stock updates from a CSV file.", details: details, actions: actions,
          recent_imports: Array(assigns[:recent_imports]).map do |item|
            { id: item.id, file_name: item.file_name, status: item.status, created_at: format_time(item.created_at), path: controller.send(:admin_import_path, item) }
          end
        }
      end

      def shopify_props
        configured = assigns[:configured]
        details = [
          { label: "Status", value: configured ? "Configured" : "Not configured" },
          { label: "Products to sync", value: assigns[:synced_count].to_i },
          { label: "Last synced", value: format_time(assigns[:last_synced]) || "Never" }
        ]
        unless configured
          details << { label: "Setup instructions", value: "Add the Shopify shop domain, client ID, and client secret to Rails credentials." }
        end
        Array(assigns[:webhooks]).each { |webhook| details << { label: "Webhook", value: webhook } }
        details << { label: "Webhook error", value: assigns[:webhook_error] } if assigns[:webhook_error].present?
        {
          view: "operations", title: "Shopify Integration", description: "Manage product, inventory, and webhook synchronization.",
          details: details,
          actions: [
            { label: "Test connection", path: controller.send(:test_connection_admin_shopify_path), method: "post" },
            { label: "Sync all", path: controller.send(:sync_all_admin_shopify_path), method: "post" },
            { label: "Register webhooks", path: controller.send(:register_webhooks_admin_shopify_path), method: "post" }
          ]
        }
      end

      def backups_props
        credentials = assigns[:credentials] || {}
        status = if assigns[:credentials_error].present?
          "Error"
        elsif !credentials[:configured]
          "Not configured"
        elsif !credentials[:connected]
          "Not connected"
        else
          "Connected"
        end
        actions = []
        if credentials[:connected]
          actions << { label: "Disconnect", path: controller.send(:disconnect_admin_backups_path), method: "delete" }
        elsif credentials[:configured]
          actions << { label: "Connect Google Drive", path: controller.send(:authorize_admin_backups_path), method: "get", full_reload: true }
        end
        files = [ [ "Database backups", assigns[:db_backups] ], [ "Garage bucket backups", assigns[:garage_backups] ] ].map do |label, records|
          {
            label: label,
            items: Array(records).map do |file|
              {
                name: file.name, created_at: format_time(file.created_time),
                size: file.size ? h.number_to_human_size(file.size.to_i) : "—",
                path: controller.send(:download_admin_backups_path, file_id: file.id, file_name: file.name)
              }
            end
          }
        end
        {
          view: "backups", title: "Backups", description: "Google Drive integration status and nightly backup files.",
          status: status,
          details: [
            { label: "Account", value: credentials[:display_name] || credentials[:email] || "—" },
            { label: "Email", value: credentials[:email] || "—" },
            { label: "Message", value: assigns[:credentials_error] || credentials[:error] || "Ready" }
          ],
          files: files, actions: actions
        }
      end

      def recurring_tasks_props
        task_rows = Array(assigns[:tasks]).map do |entry|
          task = entry[:task]
          {
            key: task.key, schedule: task.schedule, class_name: task.class_name,
            last_run_at: format_time(entry[:last_run_at]), last_job_status: entry[:last_job_status].to_s.humanize,
            run_path: controller.send(:run_admin_recurring_task_path, task)
          }
        end
        {
          view: "recurring_tasks", title: "Recurring Tasks", description: "Review schedules and manually enqueue supported jobs.",
          recurring_tasks: task_rows, actions: []
        }
      end

      def data_export_props
        {
          view: "operations", title: "Data Export", description: "Download the application data as an Excel workbook.",
          details: Array(assigns[:export_tables]).map { |table| { label: "Table", value: table.to_s.titleize } },
          actions: [ { label: "Download Excel export", path: controller.send(:admin_data_export_path), method: "post", full_reload: true } ]
        }
      end

      def restocks_props
        {
          view: "operations", title: "Restock History", description: assigns[:product]&.name.to_s,
          details: Array(assigns[:restocks]).map do |restock|
            {
              label: format_time(restock.created_at),
              value: "#{restock.quantity} units by #{human_label(restock.user)}#{restock.notes.present? ? " — #{restock.notes}" : ""}"
            }
          end,
          actions: []
        }
      end

      def receipt_template_props
        template = assigns[:receipt_template]
        {
          view: "receipt_template_show", title: template.name, description: "Receipt layout and print preview.",
          details: RESOURCE_CONFIGS.fetch("admin_area/receipt_templates")[:show].map { |key| { label: key.to_s.humanize, value: display_value(template, key) } },
          preview_lines: Array(assigns[:preview_lines]),
          actions: {
            index: controller.send(:admin_receipt_templates_path), edit: controller.send(:edit_admin_receipt_template_path, template),
            activate: template.active? ? nil : controller.send(:activate_admin_receipt_template_path, template),
            delete: controller.send(:admin_receipt_template_path, template)
          }
        }
      end

      def operational_controller?
        %w[dev_tools].include?(controller_path)
      end

      def operational_props
        title = controller_path.split("/").last.humanize
        title = "Stock Imports" if controller_path == "admin_area/imports"
        details = presenter_assigns.flat_map do |key, value|
          operational_detail_rows(key, value)
        end
        actions = operational_actions
        {
          view: "operations", title: title, description: "Administrative status and controls.",
          details: details, actions: actions
        }
      end

      def operational_detail_rows(key, value)
        case value
        when ActiveRecord::Base
          [ { label: key.to_s.humanize, value: record_label(value, singular: value.class.model_name.human) } ] +
            value.attributes.except("password_digest").map { |attribute, attribute_value| { label: attribute.humanize, value: format_scalar(attribute_value) } }
        when Array, ActiveRecord::Relation
          Array(value).first(50).map { |item| { label: key.to_s.humanize.singularize, value: item.is_a?(Hash) ? item.transform_values { |entry| format_scalar(entry) } : human_label(item) } }
        when Hash
          value.map { |nested_key, nested_value| { label: nested_key.to_s.humanize, value: format_scalar(nested_value) } }
        else
          [ { label: key.to_s.humanize, value: format_scalar(value) } ]
        end
      end

      def operational_actions
        case controller_path
        when "admin_area/imports"
          [ { label: "Upload CSV", path: controller.send(:admin_imports_path), method: "post", upload: true } ]
        when "admin_area/shopify"
          [
            { label: "Test connection", path: controller.send(:test_connection_admin_shopify_path), method: "post" },
            { label: "Sync all", path: controller.send(:sync_all_admin_shopify_path), method: "post" },
            { label: "Register webhooks", path: controller.send(:register_webhooks_admin_shopify_path), method: "post" }
          ]
        when "admin_area/backups"
          [ { label: "Connect Google Drive", path: controller.send(:authorize_admin_backups_path), method: "get" } ]
        when "admin_area/data_exports"
          [ { label: "Download Excel export", path: controller.send(:admin_data_export_path), method: "post", full_reload: true } ]
        else []
        end
      end

      def generic_props
        {
          view: "operations",
          title: controller_path.split("/").last.humanize,
          description: action_name.humanize,
          details: presenter_assigns.flat_map { |key, value| operational_detail_rows(key, value) },
          actions: []
        }
      end

      def form_field_props(field, record)
        key, label, type, required, options = field
        options ||= {}
        value = if %i[password password_confirmation images logo].include?(key)
          type == :file ? nil : ""
        elsif record&.respond_to?(key)
          serializable_value(record.public_send(key), type)
        end
        value = value.to_d * 100 if key == :rate && value.present?

        {
          key: key.to_s, label: label, type: type.to_s, required: required,
          value: value, options: select_options(options[:source]),
          step: options[:step], min: options[:min], multiple: options[:multiple], accept: options[:accept]
        }.compact
      end

      def select_options(source)
        case source
        when :tax_codes then model_options(TaxCode.kept.order(:code), :code)
        when :suppliers then model_options(Supplier.kept.order(:name), :name)
        when :product_groups then model_options(ProductGroup.order(:name), :name)
        when :categories then model_options(Category.kept.order(:name), :name)
        when :discounts then model_options(Discount.kept.currently_active.order(:name), :name)
        when :users then User.order(:name).map { |user| { value: user.id.to_s, label: human_label(user) } }
        when :store_task_statuses then StoreTask.statuses.keys.map { |value| { value: value, label: value.humanize } }
        when :discount_types then Discount.discount_types.keys.map { |value| { value: value, label: value.humanize } }
        when :user_types then %w[Common Admin].map { |value| { value: value, label: value } }
        when :themes then %w[light dark dim].map { |value| { value: value, label: value.humanize } }
        when :font_sizes then %w[default large xlarge].map { |value| { value: value, label: value.humanize } }
        when :accent_colors then Store::ACCENT_COLOR_NAMES.map { |value| { value: value, label: value.to_s.titleize } }
        when :paper_widths then ReceiptTemplate::PAPER_WIDTHS.map { |value, data| { value: value.to_s, label: data[:label] } }
        else []
        end
      end

      def model_options(scope, display)
        scope.map { |record| { value: record.id.to_s, label: record.public_send(display).to_s } }
      end

      def serializable_value(value, type)
        return value.map(&:to_s) if type == :multiselect
        return value.strftime("%Y-%m-%dT%H:%M") if type == :datetime_local && value.respond_to?(:strftime)
        return value.iso8601 if type == :date && value.respond_to?(:iso8601)
        value
      end

      def index_row(record, columns, config)
        {
          id: record.id,
          label: record_label(record, config),
          values: columns.to_h { |column| [ column[:key], display_value(record, column[:key]) ] },
          show_path: record_path(record, config),
          edit_path: edit_resource_path(record, config)
        }
      end

      def fallback_columns(record)
        return [] unless record
        record.attributes.except("password_digest", "metadata", "discarded_at").keys.first(7).map { |key| { key: key, label: key.humanize, default: true, sortable: false } }
      end

      def display_value(record, key)
        key = key.to_sym
        value = case key
        when :supplier, :tax_code, :product_group, :assigned_to, :generated_by, :opened_by, :closed_by, :customer, :sold_on_order
          record.respond_to?(key) ? record.public_send(key) : nil
        when :assigned_to_id then record.respond_to?(:assigned_to) ? record.assigned_to : nil
        when :categories then record.respond_to?(:categories) ? record.categories.to_a : []
        when :address
          %i[address_line1 address_line2 city province postal_code country].filter_map { |part| record.public_send(part).presence if record.respond_to?(part) }.join(", ")
        when :diff
          record.respond_to?(:discrepancy_cents) ? h.number_to_currency(record.discrepancy_cents.to_i / 100.0) : nil
        when :record
          "#{record.auditable_type} ##{record.auditable_id}" if record.respond_to?(:auditable_type)
        when :user
          record.respond_to?(:user) ? record.user : nil
        when :details
          record.respond_to?(:audited_changes) ? record.audited_changes : nil
        when :created_at, :updated_at
          if record.has_attribute?(key)
            record.public_send(key)
          elsif record.has_attribute?("#{key}_s")
            Time.zone.parse(record.public_send("#{key}_s"))
          end
        else
          record.public_send(key) if record.respond_to?(key)
        end
        format_scalar(value, key: key)
      rescue ActiveModel::MissingAttributeError
        "—"
      end

      def format_scalar(value, key: nil)
        return "—" if value.nil? || value == ""
        return value.map { |item| human_label(item) }.join(", ") if value.is_a?(Array)
        return value.to_json if value.is_a?(Hash)
        return human_label(value) if value.is_a?(ActiveRecord::Base)
        return value ? "Yes" : "No" if value.in?([ true, false ])
        return format_time(value) if value.respond_to?(:strftime)
        return value if value.is_a?(String)
        return value.to_s.humanize if value.is_a?(Symbol)
        if value.is_a?(BigDecimal) && key.to_s.match?(/price|cost|total|amount|balance/)
          return h.number_to_currency(value)
        end
        value.to_s.humanize
      end

      def presenter_assigns
        assigns.reject { |key, value| key.to_s.in?(%w[_routes inertia_shared]) || value.is_a?(Proc) }
      end

      def format_time(value)
        return nil unless value
        value.respond_to?(:strftime) ? value.strftime("%b %-d, %Y %-l:%M %p") : value.to_s
      end

      def human_label(record)
        return "—" unless record
        return record.title if record.respond_to?(:title) && record.title.present?
        return record.number if record.respond_to?(:number) && record.number.present?
        return record.name if record.respond_to?(:name) && record.name.present?
        return record.email_address if record.respond_to?(:email_address) && record.email_address.present?
        return record.code if record.respond_to?(:code) && record.code.present?
        record.to_s
      end

      def record_label(record, config = nil, singular: nil)
        singular ||= config&.dig(:singular) || record.class.model_name.human
        label = human_label(record)
        label == record.to_s ? "#{singular} ##{record.id}" : label
      end

      def collection_path(config)
        if config[:admin]
          controller.send(:polymorphic_path, [ :admin, config[:record].to_s.pluralize.to_sym ])
        elsif config[:collection] == :held_orders
          controller.send(:held_orders_path)
        elsif config[:collection] == :sessions
          controller.send(:history_cash_drawer_path)
        else
          controller.send(:polymorphic_path, config[:record].to_s.pluralize.to_sym)
        end
      rescue ActionController::UrlGenerationError, NoMethodError
        controller.request.path
      end

      def record_path(record, config)
        config[:admin] ? controller.send(:polymorphic_path, [ :admin, record ]) : controller.send(:polymorphic_path, record)
      rescue ActionController::UrlGenerationError, NoMethodError
        controller.request.path
      end

      def edit_resource_path(record, config)
        return nil unless record && record.respond_to?(:persisted?) && record.persisted?
        config[:admin] ? controller.send(:edit_polymorphic_path, [ :admin, record ]) : controller.send(:edit_polymorphic_path, record)
      rescue ActionController::UrlGenerationError, NoMethodError
        nil
      end

      def new_resource_path(config)
        config[:admin] ? controller.send(:new_polymorphic_path, [ :admin, config[:record].to_s.to_sym ]) : controller.send(:new_polymorphic_path, config[:record].to_s.to_sym)
      rescue ActionController::UrlGenerationError, NoMethodError
        nil
      end

      def can_create?(config)
        controller.send(:can?, :create, config[:record].to_s.classify.safe_constantize)
      rescue StandardError
        true
      end

      def pagination_props(pagy)
        return nil unless pagy
        {
          page: pagy.page, pages: pagy.last, count: pagy.count,
          previous: pagy.prev, next: pagy.next, limit: pagy.limit
        }
      rescue NoMethodError
        nil
      end

      def safe_query_params
        params.to_unsafe_h.except("controller", "action", "id").transform_values do |value|
          value.is_a?(ActionController::Parameters) ? value.to_unsafe_h : value
        end
      end

      def safe_public_path(method_name)
        controller.send(method_name) if method_name.present? && controller.respond_to?(method_name, true)
      rescue ActionController::UrlGenerationError
        nil
      end

      def safe_attributes(record, keys)
        return nil unless record
        keys.to_h { |key| [ key, record.public_send(key) ] }
      end

      def order_summary(order)
        {
          id: order.id, number: order.number, status: order.status,
          customer: order.customer_name, total: h.number_to_currency(order.total),
          line_count: order.order_lines.size, created_at: format_time(order.created_at),
          path: controller.send(:order_path, order), register_path: controller.send(:register_path, order_id: order.id)
        }
      end

      def order_props(order)
        return nil unless order
        {
          id: order.id, number: order.number, status: order.status, customer: order.customer && { id: order.customer.id, name: order.customer.name, alert: order.customer.alert },
          created_by: human_label(order.created_by), notes: order.notes, tax_exempt: order.tax_exempt,
          subtotal: h.number_to_currency(order.subtotal), discount_total: h.number_to_currency(order.discount_total),
          tax_total: h.number_to_currency(order.tax_total), total: h.number_to_currency(order.total),
          amount_paid: h.number_to_currency(order.amount_paid),
          balance_due: h.number_to_currency(order.amount_remaining), balance_due_value: order.amount_remaining.to_f,
          payment_complete: order.payment_complete?, completed_at: format_time(order.completed_at),
          lines: order.order_lines.sort_by(&:position).map { |line| order_line_props(line) },
          discounts: order.order_discounts.map do |discount|
            {
              id: discount.id, name: discount.name, display_value: discount.display_value,
              amount: h.number_to_currency(discount.calculated_amount), auto_applied: discount.auto_applied?,
              path: controller.send(:order_discount_path, discount)
            }
          end,
          line_discounts: order.order_line_discounts.group_by(&:name).map do |name, discounts|
            {
              name: name, display_value: discounts.first.display_value,
              applied_quantity: discounts.sum(&:applied_quantity),
              total_quantity: discounts.sum { |discount| discount.order_line.quantity },
              amount: h.number_to_currency(discounts.sum(&:calculated_amount)),
              auto_applied: discounts.all?(&:auto_applied?)
            }
          end,
          payments: order.order_payments.map do |payment|
            {
              id: payment.id, method: payment.display_method, amount: h.number_to_currency(payment.amount),
              tendered: payment.amount_tendered && h.number_to_currency(payment.amount_tendered),
              change: payment.change_given && h.number_to_currency(payment.change_given),
              reference: payment.reference, path: controller.send(:order_payment_path, payment)
            }
          end
        }
      end

      def order_line_props(line)
        {
          id: line.id, code: line.code, name: line.name, quantity: line.quantity, sellable_type: line.sellable_type,
          refundable_quantity: [ line.quantity - line.refund_lines.sum(:quantity), 0 ].max,
          unit_price: h.number_to_currency(line.unit_price), discount: h.number_to_currency(line.discount_amount),
          tax: h.number_to_currency(line.tax_amount), total: h.number_to_currency(line.line_total),
          discounts: line.order_line_discounts.map do |discount|
            {
              id: discount.id, name: discount.name, display_value: discount.display_value,
              amount: h.number_to_currency(discount.calculated_amount), auto_applied: discount.auto_applied?,
              applied_quantity: discount.applied_quantity, excluded_quantity: discount.excluded_quantity,
              update_path: controller.send(:order_line_discount_path, discount),
              delete_path: controller.send(:order_line_discount_path, discount)
            }
          end,
          update_path: controller.send(:order_line_path, line), delete_path: controller.send(:order_line_path, line)
        }
      end

      def task_summary(task)
        { id: task.id, title: task.title, status: task.status, due_date: task.due_date&.iso8601, overdue: task.overdue?, path: controller.send(:store_task_path, task) }
      end

      def drawer_props(session)
        return nil unless session
        {
          id: session.id, opened_at: format_time(session.opened_at), opened_by: human_label(session.opened_by),
          opening_total: h.number_to_currency(session.opening_total), closed_at: format_time(session.closed_at),
          closed_by: human_label(session.closed_by), closing_total: session.closed_at ? h.number_to_currency(session.closing_total) : nil,
          discrepancy: session.closed_at ? h.number_to_currency(session.discrepancy) : nil, notes: session.notes,
          path: session.closed_at ? controller.send(:session_detail_cash_drawer_path, session) : nil
        }
      end
  end
end
