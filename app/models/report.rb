# frozen_string_literal: true

class Report < ApplicationRecord
  audited except: [ :result_data ]

  include PgSearch::Model

  pg_search_scope :search, against: [ :title, :report_type, :status ],
    using: { tsearch: { prefix: true }, trigram: {} }

  STATUSES = %w[pending processing completed failed].freeze

  belongs_to :generated_by, class_name: "User"

  validates :report_type, presence: true
  validates :title, presence: true
  validates :status, presence: true, inclusion: { in: STATUSES }

  scope :recent, -> { order(created_at: :desc) }
  scope :completed, -> { where(status: "completed") }
  scope :by_status, ->(status) { where(status: status) if status.present? }
  scope :by_report_type, ->(type) { where(report_type: type) if type.present? }

  def pending?    = status == "pending"
  def processing? = status == "processing"
  def completed?  = status == "completed"
  def failed?     = status == "failed"

  def template
    ReportTemplate.find(report_type)
  end

  def duration
    return unless started_at && completed_at

    completed_at - started_at
  end
end
