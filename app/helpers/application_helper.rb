# frozen_string_literal: true

module ApplicationHelper
  include Pagy::Method

  def audit_auditable_label(audit)
    record = audit.auditable
    return "#{audit.auditable_type} ##{audit.auditable_id}" unless record

    case audit.auditable_type
    when "User" then record.name.presence || record.email_address
    when "Product" then record.name
    when "ProductVariant" then record.code.presence || record.name.presence || "Variant ##{record.id}"
    when "Service" then record.name
    when "TaxCode" then record.code
    when "Supplier" then record.name
    when "Category" then record.name
    else "#{audit.auditable_type} ##{audit.auditable_id}"
    end
  end

  def audit_auditable_path(audit)
    record = audit.auditable
    return nil unless record

    case audit.auditable_type
    when "User" then user_path(record)
    when "Product" then product_path(record)
    when "ProductVariant" then record.product ? product_product_variant_path(record.product, record) : nil
    when "Service" then service_path(record)
    when "TaxCode" then admin_tax_code_path(record)
    when "Supplier" then admin_supplier_path(record)
    when "Category" then nil
    else nil
    end
  end

  def format_audit_value(value)
    case value
    when nil, "" then "—"
    when true then "Yes"
    when false then "No"
    when Time, DateTime, ActiveSupport::TimeWithZone then l(value, format: :short)
    when Date then l(value, format: :short)
    when Integer then number_with_delimiter(value)
    else value.to_s
    end
  end
end
