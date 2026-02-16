# frozen_string_literal: true

module ApplicationHelper
  include Pagy::Method

  def nav_section_active?(path_or_prefix)
    path = path_or_prefix.to_s
    return current_page?(root_path) if path.blank? || path == "/"

    request.path.start_with?(path)
  end

  def mapbox_access_token
    Rails.application.credentials.dig(:mapbox, :access_token).presence || ENV["MAPBOX_ACCESS_TOKEN"].presence
  end

  def audit_auditable_label(audit)
    record = audit.auditable
    return "#{audit.auditable_type} ##{audit.auditable_id}" unless record

    case audit.auditable_type
    when "User" then record.name.presence || record.email_address
    when "Product" then record.name.presence || record.code
    when "Service" then record.name
    when "TaxCode" then record.code
    when "Supplier" then record.name
    when "Category" then record.name
    when "Store" then record.name.presence || "Store"
    when "Customer" then record.name
    else "#{audit.auditable_type} ##{audit.auditable_id}"
    end
  end

  def audit_auditable_path(audit)
    record = audit.auditable
    return nil unless record

    case audit.auditable_type
    when "User" then admin_user_path(record)
    when "Product" then product_path(record)
    when "Service" then service_path(record)
    when "TaxCode" then admin_tax_code_path(record)
    when "Supplier" then admin_supplier_path(record)
    when "Category" then nil
    when "Store" then admin_store_path
    when "Customer" then customer_path(record)
    else nil
    end
  end

  def format_audit_value(value)
    case value
    when nil, "" then "—"
    when true then "Yes"
    when false then "No"
    when Time, DateTime, ActiveSupport::TimeWithZone then local_time(value, format: :short)
    when Date then l(value, format: :short)
    when Integer then number_with_delimiter(value)
    else value.to_s
    end
  end

  # Renders a themed status chip.
  #
  # Variants: :success, :error, :warning, :info, :neutral
  #
  # Usage:
  #   status_chip("Completed", :success)
  #   status_chip("Failed", :error)
  #
  def status_chip(label, variant = :neutral)
    variant_class = "status-chip-#{variant}"
    tag.span(label, class: "status-chip #{variant_class}")
  end

  # Generates a <style> tag that overrides the CSS accent custom properties
  # based on the store's configured accent colour.  Returns an empty string
  # when the default (teal) is selected so no extra CSS is injected.
  def accent_color_style_tag
    store = Store.current
    return "".html_safe if store.accent_color == "teal"

    palette = store.accent_palette
    tag.style(<<~CSS.html_safe, nonce: true)
      :root, [data-theme="light"] {
        --color-accent: #{palette[:light]};
        --color-accent-hover: #{palette[:light_hover]};
      }
      [data-theme="dark"] {
        --color-accent: #{palette[:dark]};
        --color-accent-hover: #{palette[:dark_hover]};
      }
      [data-theme="dim"] {
        --color-accent: #{palette[:dark]};
        --color-accent-hover: #{palette[:dark_hover]};
      }
    CSS
  end
end
