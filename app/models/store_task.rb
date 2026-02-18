# frozen_string_literal: true

class StoreTask < ApplicationRecord
  audited

  # === Associations ===
  belongs_to :assigned_to, class_name: "User", optional: true

  # === Enums ===
  enum :status, { not_started: 0, in_progress: 1, blocked: 2, done: 3 }

  # === Validations ===
  validates :title, presence: true, length: { maximum: 255 }

  # === Scopes ===
  scope :overdue, -> { where.not(status: :done).where("due_date < ?", Date.current) }
  scope :upcoming, -> { where.not(status: :done).where("due_date >= ?", Date.current) }
  scope :assigned_to_user, ->(user) { where(assigned_to: user) }
  scope :recent, -> { order(created_at: :desc) }

  # === Instance Methods ===

  def overdue?
    due_date.present? && !done? && due_date < Date.current
  end

  def status_label
    status.humanize.titleize
  end
end
