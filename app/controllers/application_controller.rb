class ApplicationController < ActionController::Base
  include Authentication
  include CanCan::ControllerAdditions
  include Pagy::Method
  # Only allow modern browsers supporting webp images, web push, badges, import maps, CSS nesting, and CSS :has.
  allow_browser versions: :modern

  helper_method :current_user

  inertia_share do
    {
      auth: {
        authenticated: authenticated?.present?,
        id: Current.user&.id,
        name: Current.user&.name,
        email: Current.user&.email_address,
        admin: Current.user.is_a?(Admin),
        theme: Current.user&.theme || "light",
        unread_notifications: Current.user&.unread_notifications_count.to_i,
        store_name: Store.current&.name
      },
      flash: {
        notice: flash[:notice],
        alert: flash[:alert]
      },
      paths: inertia_paths
    }
  end

  rescue_from CanCan::AccessDenied do
    redirect_to(root_path, alert: "Not authorized.", status: :see_other)
  end

  def default_render
    if request.get? && request.format.to_sym == :html
      render inertia: "page", props: Ui::PagePresenter.new(self).call
    else
      super
    end
  end

  private

    def current_user
      Current.user
    end

    def inertia_paths
      {
        root: root_path,
        register: register_path,
        orders: orders_path,
        products: products_path,
        services: services_path,
        customers: customers_path,
        inventory: inventory_path,
        store_tasks: store_tasks_path,
        reports: reports_path,
        offline: offline_path,
        cash_drawer: cash_drawer_path,
        notifications: notifications_path,
        profile: edit_profile_path,
        admin_settings: admin_settings_path,
        admin_store: admin_store_path,
        admin_users: admin_users_path,
        admin_tax_codes: admin_tax_codes_path,
        admin_suppliers: admin_suppliers_path,
        admin_discounts: admin_discounts_path,
        admin_gift_certificates: admin_gift_certificates_path,
        admin_receipt_templates: admin_receipt_templates_path,
        admin_imports: new_admin_import_path,
        admin_shopify: admin_shopify_path,
        admin_backups: admin_backups_path,
        admin_audits: admin_audits_path,
        admin_recurring_tasks: admin_recurring_tasks_path,
        admin_data_export: admin_data_export_path,
        session: session_path,
        new_session: new_session_path,
        new_password: new_password_path
      }
    end

    def render_inertia_page(status: :ok, action: nil, path: nil)
      render inertia: "page", props: Ui::PagePresenter.new(self, action_name: action, controller_path: path).call, status: status
    end

    # Replace dashes (and other tsquery-unsafe characters) with spaces
    # so codes like "WH-BLK-001" become "WH BLK 001" and don't break
    # PostgreSQL's to_tsquery parser.
    def sanitize_search_query(query)
      query.to_s.gsub(/[-]/, " ").squish.presence
    end
end
