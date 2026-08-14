target :order_lifecycle_services do
  signature "sig"

  # DiscountItem exposes both an enum value and a scope named `allowed`, which
  # rbs_rails currently emits as duplicate declarations. This target does not
  # depend on that model, so leave its generated signature outside the boundary.
  ignore_signature "sig/rbs_rails/app/models/discount_item.rbs"

  check "app/services/orders/cancel.rb"
  check "app/services/orders/complete.rb"
  check "app/services/orders/hold.rb"
  check "app/services/orders/record_event.rb"
  check "app/services/orders/resume.rb"
end
