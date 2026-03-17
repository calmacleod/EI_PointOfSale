# frozen_string_literal: true

class NotificationsController < ApplicationController
  def index
    @notifications = current_user.notifications.persistent.recent
    @unread_count = current_user.unread_notifications_count

    render layout: false if request.headers["Turbo-Frame"]
  end

  def mark_read
    notification = current_user.notifications.find(params[:id])
    notification.mark_as_read!

    respond_to do |format|
      format.json { render json: { unread_count: current_user.reload.unread_notifications_count } }
      format.html { redirect_back_or_to root_path }
    end
  end

  def mark_all_read
    current_user.notifications.persistent.unread.update_all(read_at: Time.current)
    current_user.update_column(:unread_notifications_count, 0)

    respond_to do |format|
      format.json { render json: { unread_count: 0 } }
      format.html { redirect_back_or_to root_path }
    end
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
