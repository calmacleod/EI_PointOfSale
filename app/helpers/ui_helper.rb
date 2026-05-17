# frozen_string_literal: true

module UiHelper
  BUTTON_BASE = "ui-button"
  BUTTON_VARIANTS = {
    primary: "ui-button-primary",
    secondary: "ui-button-secondary",
    ghost: "ui-button-ghost",
    danger: "ui-button-danger",
    success: "ui-button-success",
    warning: "ui-button-warning"
  }.freeze
  BUTTON_SIZES = {
    xs: "ui-button-xs",
    sm: "ui-button-sm",
    md: nil,
    lg: "ui-button-lg"
  }.freeze

  def ui_button_class(variant: :secondary, size: :md, class_name: nil)
    [
      BUTTON_BASE,
      BUTTON_VARIANTS.fetch(variant.to_sym, BUTTON_VARIANTS[:secondary]),
      BUTTON_SIZES.fetch(size.to_sym, nil),
      class_name
    ].compact.join(" ")
  end

  def ui_card_class(interactive: false, class_name: nil)
    [
      "ui-card",
      ("ui-card-interactive" if interactive),
      class_name
    ].compact.join(" ")
  end

  def order_status_chip(order_or_status)
    status = order_or_status.respond_to?(:status) ? order_or_status.status : order_or_status.to_s
    label = order_or_status.respond_to?(:display_status) ? order_or_status.display_status : status.to_s.humanize
    variant = case status
    when "draft" then :info
    when "held" then :warning
    when "completed" then :success
    when "voided", "cancelled" then :error
    when "refunded", "partially_refunded" then :neutral
    else :neutral
    end

    status_chip(label, variant)
  end

  def boolean_status_chip(value, true_label: "Yes", false_label: "No")
    status_chip(value ? true_label : false_label, value ? :success : :neutral)
  end
end
