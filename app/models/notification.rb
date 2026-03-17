# frozen_string_literal: true

class Notification < ApplicationRecord
  belongs_to :user

  validates :title, presence: true

  scope :unread, -> { where(read_at: nil) }
  scope :persistent, -> { where(persistent: true) }
  scope :recent, -> { order(created_at: :desc).limit(20) }

  after_create  :increment_unread_count, if: -> { persistent? && !read? }
  after_update  :adjust_unread_count,    if: -> { persistent? && saved_change_to_read_at? }
  after_destroy :decrement_unread_count, if: -> { persistent? && !read? }

  def read?
    read_at.present?
  end

  def mark_as_read!
    update!(read_at: Time.current) unless read?
  end

  private

  def increment_unread_count
    user.increment!(:unread_notifications_count)
  end

  def decrement_unread_count
    user.decrement!(:unread_notifications_count)
  end

  def adjust_unread_count
    if read_at_before_last_save.nil? && read_at.present?
      user.decrement!(:unread_notifications_count)
    elsif read_at_before_last_save.present? && read_at.nil?
      user.increment!(:unread_notifications_count)
    end
  end
end
