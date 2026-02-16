class DataImport < ApplicationRecord
  belongs_to :imported_by, class_name: "User", optional: true

  has_one_attached :file

  validates :status, inclusion: { in: %w[pending processing completed failed] }

  scope :recent, -> { order(created_at: :desc) }

  def processing?
    status == "processing"
  end

  def completed?
    status == "completed"
  end

  def failed?
    status == "failed"
  end

  def progress_percentage
    return 0 if total_rows.nil? || total_rows.zero?
    ((processed_rows.to_f / total_rows) * 100).round
  end
end
