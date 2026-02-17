# frozen_string_literal: true

# Immutable audit log entry for order mutations.
# Records are append-only — never updated or deleted.
class OrderEvent < ApplicationRecord
  belongs_to :order
  belongs_to :actor, class_name: "User"

  validates :event_type, presence: true

  # Prevent any updates to persisted records.
  before_update { raise ActiveRecord::ReadOnlyRecord, "OrderEvent records are immutable" }
  before_destroy { raise ActiveRecord::ReadOnlyRecord, "OrderEvent records cannot be deleted" }

  EVENT_TYPES = %w[
    created
    line_added
    line_removed
    line_quantity_changed
    discount_applied
    discount_removed
    customer_assigned
    customer_removed
    payment_added
    payment_removed
    held
    resumed
    completed
    voided
    cancelled
    refund_processed
  ].freeze

  validates :event_type, inclusion: { in: EVENT_TYPES }

  scope :chronological, -> { order(created_at: :asc) }
  scope :recent, -> { order(created_at: :desc) }

  def description
    case event_type
    when "created"               then "Order created"
    when "line_added"            then "Added #{data['name']} (qty #{data['quantity']})"
    when "line_removed"          then "Removed #{data['name']}"
    when "line_quantity_changed" then "Changed #{data['name']} qty to #{data['new_quantity']}"
    when "discount_applied"      then "Applied discount: #{data['name']}"
    when "discount_removed"      then "Removed discount: #{data['name']}"
    when "customer_assigned"     then "Assigned customer: #{data['customer_name']}"
    when "customer_removed"      then "Removed customer"
    when "payment_added"         then "Added #{data['method']} payment: $#{data['amount']}"
    when "payment_removed"       then "Removed #{data['method']} payment: $#{data['amount']}"
    when "held"                  then "Order put on hold"
    when "resumed"               then "Order resumed from hold"
    when "completed"             then "Order completed"
    when "voided"                then "Order voided"
    when "cancelled"             then "Order cancelled"
    when "refund_processed"      then "Refund processed: $#{data['total']}"
    else event_type.humanize
    end
  end
end
