# frozen_string_literal: true

class NotificationsController < ApplicationController
  def index
    @notifications = current_user.notifications.persistent.recent
    @unread_count = current_user.notifications.persistent.unread.count

    render layout: false if request.headers["Turbo-Frame"]
  end

  def mark_read
    notification = current_user.notifications.find(params[:id])
    notification.mark_as_read!

    head :ok
  end

  def mark_all_read
    current_user.notifications.persistent.unread.update_all(read_at: Time.current)

    head :ok
  end

  def destroy
    notification = current_user.notifications.find(params[:id])
    notification.destroy

    head :ok
  end

  def clear_all
    current_user.notifications.persistent.destroy_all

    head :ok
  end
end
