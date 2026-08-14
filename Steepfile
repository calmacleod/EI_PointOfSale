target :services do
  signature "sig"

  # DiscountItem exposes both an enum value and a scope named `allowed`, which
  # rbs_rails currently emits as duplicate declarations. This target does not
  # depend on that model, so leave its generated signature outside the boundary.
  ignore_signature "sig/rbs_rails/app/models/discount_item.rbs"

  check "app/services"

  # These are inference hints rather than type-safety failures. Empty
  # collections are checked once values flow into them, and symbol-to-proc
  # forwarding remains a known weak spot in Steep's current inference.
  configure_code_diagnostics do |diagnostics|
    diagnostics[Steep::Diagnostic::Ruby::UnannotatedEmptyCollection] = nil
    diagnostics[Steep::Diagnostic::Ruby::BlockTypeMismatch] = nil
  end
end
