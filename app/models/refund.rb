# frozen_string_literal: true

# Immutable record of a refund against a completed order.
class Refund < ApplicationRecord
  belongs_to :order
  belongs_to :processed_by, class_name: "User"

  has_many :refund_lines, dependent: :destroy

  enum :refund_type, { full: 0, partial: 1 }

  validates :refund_number, presence: true, uniqueness: true
  validates :refund_type, presence: true
  validates :total, presence: true, numericality: { greater_than: 0 }

  before_validation :generate_refund_number, on: :create

  # Prevent modification after creation.
  before_update { raise ActiveRecord::ReadOnlyRecord, "Refund records are immutable" }
  before_destroy { raise ActiveRecord::ReadOnlyRecord, "Refund records cannot be deleted" }

  private

    def generate_refund_number
      return if refund_number.present?

      last_number = Refund.unscoped.maximum(:refund_number)
      next_seq = if last_number.present?
        last_number.delete_prefix("REF-").to_i + 1
      else
        1
      end

      self.refund_number = "REF-#{next_seq.to_s.rjust(6, '0')}"
    end
end
